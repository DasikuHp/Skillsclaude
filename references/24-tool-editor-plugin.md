## 24. @tool, EditorPlugin y generación procedural

Los tres lentes coinciden en lo esencial, y esa coincidencia define la verdad operativa: el dolor con `@tool` casi nunca es de API, es que **tu código corre dentro del proceso del editor, un mundo que la IA no observa**, y sus efectos secundarios (nodos huérfanos, recursos sin persistir, `.tscn` corrupto, freeze del editor) ocurren fuera del runtime del juego. Una IA ciega al editor escribe código "correcto", el dev lo ejecuta y el resultado es silenciosamente roto. Esta sección está organizada para que una IA emita código que no se atasque a ciegas.

### Enfoque nativo recomendado

Godot ofrece 4 niveles de "código en editor", de menor a mayor compromiso. El error #1 de IA es saltar a `EditorPlugin` cuando bastaba `@tool`. Elige la capa mínima que resuelve:

| Necesidad | Mecanismo | Vive en |
|---|---|---|
| Previsualizar/actualizar un nodo mientras editas la escena | `@tool` en el script del nodo | el `.gd` del nodo |
| Botón "Generar" en el inspector de ese nodo | `@export_tool_button` (4.4+) | el `.gd` del nodo (`@tool`) |
| Tipo reutilizable en "Add Node" / dock / importer / gizmo persistente | `EditorPlugin` (addon) | `addons/<x>/plugin.cfg` + `plugin.gd` |
| Datos editables en inspector | custom `Resource` con `@export` (NO necesita `@tool` salvo lógica reactiva) | el `.gd` que `extends Resource` |

Regla canónica: **`@tool` solo afecta al script donde está la anotación; no se hereda ni se propaga a hijos.** Y para addons: *"all GDScript files used by an EditorPlugin must also be `@tool` scripts, or they will behave as empty files in the editor."* Si olvidas `@tool` en el `EditorPlugin`, **el plugin no carga y no hay error obvio**.

**El guardia central** es `Engine.is_editor_hint() -> bool`: `true` dentro del editor, `false` en runtime de juego. Todo bloque que toque escena de juego, autoloads, singletons de gameplay o `get_node` de hijos solo-runtime va envuelto en `if not Engine.is_editor_hint(): return`. Sin esa guardia, la lógica de juego corre dentro del editor: desde "raro" hasta **segfault al abrir la escena**, lo que impide editar el script desde Godot (GH-58883, GH-54999).

Hechos exactos del ciclo de vida en editor: `_ready`, `_enter_tree`, `_process`, `_physics_process` y los setters **SÍ corren** en editor con `@tool`. `_process`/`_physics_process` están deshabilitados por defecto para nodos `@tool` recién instanciados (requieren `set_process(true)`), y rara vez los quieres en editor (queman CPU → freeze). Cambiar `@tool` **no recarga** una escena abierta: hay que cerrar/reabrir o reiniciar.

**Reactividad correcta:** usa setters de propiedad, NO `_process`. El inspector dispara el setter al editar; ese es el "frame de actualización". Pero el setter dispara también **durante la deserialización de la escena**, cuando los hijos aún no existen → protege con `if not is_node_ready(): return`.

**Botón de inspector (4.4+, vigente en 4.6):** `@export_tool_button("Etiqueta", "IconName") var x: Callable = metodo`. La var DEBE ser `Callable`; el 2º argumento es opcional y nombra un icono del tema `EditorIcons` (nombre de archivo de `editor/icons/`, case-sensitive; el default es `"Callable"`). En C# debe estar en clase `[Tool]` y ser propiedad expression-bodied, o salen los diagnósticos `GD0108` (no está en tool class) y `GD0111` (no es expression-bodied). El viejo hack `@export var bool` con setter auto-reseteado queda obsoleto.

### Generación procedural — el contrato de persistencia

Para 3D usa **`GridMap.set_cell_item(position: Vector3i, item: int, orientation: int = 0)`** — NO `set_cell()`, que es TileMap 2D (confusión recurrente de IA). Claves nicho:
- `item` es un **ID del `MeshLibrary`**, no un índice arbitrario. Léelos con `mesh_library.find_item_by_name(...)` / `get_item_list()`. Un ID inexistente = celda vacía silenciosa. `GridMap.INVALID_CELL_ITEM` (`-1`) borra.
- `orientation` NO son grados: es un índice de ortho-rotación (0–23). Construye un `Basis` ortogonal y conviértelo; pasar `90` rota mal.
- GridMap es **un solo nodo que serializa sus propias celdas** → no necesita owner por celda. Esa es su ventaja sobre instanciar miles de nodos sueltos.

**El pitfall que corrompe escenas (`owner`):** si en lugar de GridMap añades nodos con `add_child`, **no se guardan en el `.tscn` salvo que les fijes `owner = get_tree().edited_scene_root`** (GH-37144, GH-95646, GH-82756). Orden obligatorio: `add_child()` PRIMERO, `owner =` DESPUÉS (asignar owner antes lanza `Condition '!is_inside_tree()' is true`). Un padre con owner NO propaga owner a sus hijos: cada descendiente que quieras guardar lo necesita. `edited_scene_root` es `null` si no hay escena abierta (p.ej. dentro de un importer) → comprueba antes.

**Decisión clave de diseño (donde los tres lentes convergen):** para mazmorras procedurales, **NO bakees al `.tscn`**. Genera en runtime (`_ready` con `is_editor_hint()` false) o en editor SIN owner (solo preview/visual). Reserva el bake-con-owner para cosas que un diseñador retocará a mano. Si bakeas con owner, **borra los hijos previos antes de regenerar** (`for c in get_children(): c.free()`) o acumulas duplicados y corrompes la escena.

Para miles de props/vegetación usa **`MultiMeshInstance3D` + `MultiMesh`** (un draw call). Orden EXACTO: fija `transform_format` (y `use_colors`/`use_custom_data` si aplica) **ANTES** de `instance_count`; tras asignar `instance_count` ya no puedes cambiar el formato, y cambiar `instance_count` **resetea** los transforms. Luego `set_instance_transform(i, t)`. Mutar `visible_instance_count` cada frame causa picos. Para 20k+ con colisión, baja a `RenderingServer`/`PhysicsServer3D`.

### Pitfalls y mensajes de error literales

| Mensaje / síntoma literal | Causa | Fix |
|---|---|---|
| Nodos visibles en viewport pero **ausentes del árbol y `.tscn`** | falta `owner` | `nodo.owner = get_tree().edited_scene_root` tras `add_child` |
| `Invalid access to property or key 'X' on a base object of type 'null instance'` | `_ready`/`_process` en editor antes de poblar `@export`, o export dejado en null | guardia `if x == null: return` + `if not Engine.is_editor_hint(): return` |
| Escena **"invalid/corrupt"**, editor crashea al abrir | tool serializó `= null` / leyó var de script padre en editor | editar `.tscn` con editor EXTERNO, borrar líneas `prop = null`; mantener tool scripts autocontenidos (GH-73905, GH-79545) |
| Editor **se congela / 100% CPU** al editar una propiedad | bucle setter → regeneración → setter, getter pesado, o `notify_property_list_changed()` re-disparando | regeneración diferida con flag `_dirty`, o botón explícito; nunca generar pesado en `_process` de editor (GH-83696, GH-111635) |
| Botón modifica un Resource pero **se pierde al reabrir** | no marcado dirty / colisión de caché | `ResourceSaver.save(res, res.resource_path)`, `take_over_path()`, o `resource_local_to_scene = true` (GH-98331) |
| Plugin **no aparece** tras activarlo | falta `@tool` en el EditorPlugin, o no reiniciaste | añadir `@tool`; desactivar/reactivar o reiniciar editor |
| Tipo custom **sigue apareciendo** tras desactivar plugin | falta `remove_custom_type` en `_exit_tree` | limpieza simétrica de TODO lo creado en `_enter_tree` |
| Gizmo nunca se dibuja, sin error | `_has_gizmo` no devuelve true / no registrado | `add_node_3d_gizmo_plugin` + `_has_gizmo(node)` → true |
| `set_cell_item` no pone nada | `item` ID inexistente en MeshLibrary | `find_item_by_name` antes; `push_error` si `< 0` |
| MultiMesh pierde todas las transforms | cambiaste `instance_count` después de setear transforms | `instance_count` primero, transforms después |
| `"Child node disappeared while duplicating"` | sub-hijos generados por tool con `owner` mal asignado al duplicar | revisar ownership; evitar bake innecesario (GH-116902) |
| Script `@tool` "no hace nada en editor" | falta `@tool` en línea 1, o no reabriste la escena | `@tool`; reabrir escena/reiniciar editor |

**Trampa de `_init()` en Resources (GH-68427):** dentro de `_init()` los `@export` aún tienen **valores por defecto**, no los serializados. No inicialices lógica dependiente de exports en `_init()`; hazlo perezosamente o en un setter.

### Cómo no quedarte atascado

Una IA no ve el editor, pero **valida headless por CLI** (esto convierte fallos invisibles en stdout parseable; recétalo SIEMPRE antes de decir "listo"):

```bash
# 1. ¿Compila el script @tool / plugin? (parsea, no ejecuta). -s == --script
# OJO: --check-only parsea, y preload() se resuelve en PARSE time. Si plugin.gd
# hace preload de scripts/icono/dock que aún no existen, esto falla con
# "Could not preload resource file" ANTES de validar nada. Crea esos stubs primero.
godot --headless --check-only --script res://addons/dungeon/plugin.gd

# 2. Re-importar recursos/.uid sin GUI (resuelve "Cannot open file ... uid://...")
godot --headless --import --quit-after 2

# 3. Ejecutar un script suelto que invoque la generación y haga asserts
godot --headless --script res://tools/test_gen.gd --quit-after 1

# 4. Abrir el proyecto, dejar correr @tool/plugin unos frames y cazar errores de _enter_tree
godot --headless --verbose --editor --quit-after 3
```

Verificación ciega del resultado: como no hay GUI, mete `assert(get_used_cells().size() > 0)` / `assert(multimesh.instance_count == N)` dentro del propio script tool — es el único "ojo" disponible.

**Procedimiento de emergencia si el editor crashea en bucle por un `@tool`:**
1. NO abras el proyecto en el editor. Edita el `.gd` ofensor con editor EXTERNO (VSCode/vim) y comenta el código tóxico.
2. Vacía la escena de arranque: en `project.godot`, `[application] run/main_scene=""`, para que el editor no cargue la escena tóxica al abrir.
3. Si el `.tscn` arrastra `[node]` huérfanos o líneas `prop = null`, ábrelo como texto plano y bórralos a mano.
4. Reimporta con `godot --headless --import` y reabre.

Reglas mentales fijas: si el síntoma "solo pasa en editor" → falta `if not Engine.is_editor_hint(): return`. Si "solo en juego" → el guardia está invertido.

### Específico 4.6 (APIs muertas que la IA arrastra)

- `.tscn` **ya no escribe `load_steps`**; los recursos usan `uid://` + archivos `.uid` (desde 4.4). Si una IA escribe `.tscn`/`.tres` a mano con `load_steps=` o paths `res://` duros donde se espera `uid://`, romperá referencias. Fix: **Project > Tools > Upgrade Project Files**, nunca escribir UIDs a mano.
- Shaders en gizmos/overlays: `SCREEN_TEXTURE`/`DEPTH_TEXTURE` eliminados → `uniform sampler2D tex : hint_screen_texture;`.
- AnimationPlayer: props del tipo *animation-NAME* pasaron de `String` a `StringName` (GH-110767) — relevante si el generador setea animaciones por código; son nombres de propiedad, NO de track.
- `@abstract` (desde 4.5): un `@tool @abstract` no es instanciable; no lo pongas en algo que el inspector intente crear en "Add Node".
- Tras actualizar a 4.6 hay un caso reportado de tool scripts que pierden acceso a vars de clases extendidas → corre Upgrade Project Files.

### Addon vs construirlo

- **Generador para TU RPG** (rooms, spawners, terreno) → **NO addon.** `@tool` + `class_name` + `@export_tool_button`. Vive en el árbol del juego, cero `plugin.cfg`, cero reinicios, se versiona con el proyecto. `class_name` registra el tipo en "Add Node" sin addon; `add_custom_type` solo se justifica si necesitas icono propio sin tocar la clase base, o que el tipo desaparezca al desactivar el plugin.
- **EditorPlugin solo si** necesitas dock/panel propio, gizmo 3D persistente (`EditorNode3DGizmoPlugin` solo se registra desde un plugin → fuerza el camino addon), importer custom (`EditorImportPlugin`), inspector custom (`EditorInspectorPlugin`), o empaquetar para AssetLib. Cuesta el ciclo activar/reiniciar y limpieza `_enter_tree`/`_exit_tree`.
- **No reinventes geometría/scatter genérico.** Para sembrar props sobre terreno, **ProtonScatter** (HungryProton/scatter, maduro, basado en MultiMesh). Para mazmorras de prefabs modulares, **SimpleDungeons** (majikayogames). Para aprender algoritmos (BSP, biomas), lee **GDQuest godot-4-procedural-generation** — léelo, no lo importes. Construye tú solo la lógica de gameplay específica (qué enemigos, qué loot por celda).

**Veredicto ponytail:** la mejor herramienta de editor es la que no escribes. Antes de tocar `EditorPlugin`, pregúntate si `@tool` + `class_name` + `@export_tool_button` ya lo resuelve — casi siempre sí. Antes de instanciar mil nodos con `owner`, usa **GridMap** o **MultiMesh** (un nodo que serializa solo, sin el infierno de ownership). Antes de bakear al `.tscn`, genera en runtime con la guardia `is_editor_hint()`. Y antes de escribir un scatter o un dungeon generator desde cero, mira ProtonScatter/SimpleDungeons. El editor es un mundo que no ves: cuanto menos código tuyo corra ahí, menos formas tienes de corromper la escena a ciegas.



> **Escalera ponytail:** rung 4 (@tool/EditorPlugin nativos) · **net propio:** un tool script mínimo; cuida no corromper la escena en editor.
