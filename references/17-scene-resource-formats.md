## 17. Formatos .tscn/.tres/project.godot y UIDs

Estos archivos son texto tipo INI que el editor de Godot trata como **fuente de verdad regenerable**. Una IA que NO ve el editor puede generarlos y editarlos a mano, pero el parser es **estricto y de una sola pasada**: orden de secciones, IDs string entre comillas, formato de tipos y referencias deben ser exactos. El campo de minas #1 son los **UIDs**: inventarlos produce warnings y refs frágiles. La regla de oro: genera el contenido determinista a mano, pero **deja que Godot asigne/repare los UIDs** (re-guardado en editor o `--headless --import`).

### Enfoque nativo recomendado

No necesitas ningún addon para generar `.tscn`/`.tres`/`project.godot`: son texto, y para crear recursos por código los singletons del core (`ResourceSaver`, `ResourceUID`, `ResourceLoader`) bastan. El "addon canónico" para regenerar UIDs y cache es el propio engine vía `godot --headless --import`.

**Lo que cambió en 4.6 (verificado en la guía oficial de upgrade):**

1. **`load_steps` se eliminó del header.** En 4.6 el engine ya **no escribe** `load_steps` al guardar (seguía siendo solo para la barra de progreso, y ensuciaba diffs/rebases en VCS). Sigue parseándolo si está presente por compatibilidad, pero lo borra al re-guardar. **Una IA generando escenas 4.6 NO debe escribir `load_steps`.** Es el primer red flag que delata texto generado con docs viejos.
2. **Cada nodo guarda un identificador entero estable** (atributo `unique_id=NNNN` en el `[node]`, p.ej. `[node name="Ball" ... unique_id=1358867382]`), distinto de los `uid://` de escena/recurso, para sobrevivir a renombrados/movimientos en herencia de escenas (refactor más robusto). Es retro/forward-compatible (escenas 4.5 cargan en 4.6 y viceversa). No lo escribas a mano ni emitas un `uid://` en un nodo; el editor lo añade solo al re-guardar.
3. **`load_steps` + `unique_id` de nodo = diff masivo** la primera vez que abres+guardas un proyecto 4.5 en 4.6. Hazlo en un commit aislado tras `Project > Tools > Upgrade Project Files...`.

**Header canónico 4.6 (sin `load_steps`):**

```ini
[gd_scene format=3 uid="uid://cecaux1sm7mo0"]
```
```ini
[gd_resource type="Resource" script_class="ItemData" format=3 uid="uid://b3qf7x2k9m1n0"]
```

`format=3` es obligatorio en 4.x (`format=2` = Godot 3). Ver ejemplos completos abajo.

**Reglas de formato que rompen al editar a mano:**

- **Orden de secciones, no reordenar:** `[gd_scene]` → todos los `[ext_resource]` → todos los `[sub_resource]` (en orden topológico: si uno referencia a otro, va después) → `[node]` → `[connection]` → `[editable]` opcional. Un `[node]` antes de su recurso = parse error de una pasada.
- **IDs son STRING entre comillas** (4.x): `id="2_abc12"`, se referencia con `ExtResource("2_abc12")` / `SubResource("CapsuleShape3D_k3m1")`. Enteros pelados (`id=2`, `ExtResource(2)`) son sintaxis de Godot 3 → corrupción. Cada `id="X"` debe casar EXACTO (comillas incluidas) con cada `ExtResource("X")`/`SubResource("X")`.
- **Paths de nodo relativos al root, SIN el nombre del root.** El root no lleva `parent=`. Hijos directos: `parent="."`. Nietos: `parent="Collision"` (no `parent="Player/Collision"`).
- **`instance=ExtResource(...)` XOR `type="..."`**, nunca ambos en el mismo `[node]`.
- **Literales de tipo:** `Vector3(0, 1, 0)`, `Color(1, 0, 0, 1)`, `Transform3D(...)` = **12 floats** (basis 9 + origen 3, NO 16), `Transform2D` = 6. `NodePath`: `^"Path/Node"`. `StringName`: `&"nombre"`. Typed arrays/dicts: `Array[int]([1, 2, 3])`, `Dictionary[StringName, int]({})`.
- **Propiedades en valor por defecto no se escriben** (el editor las descarta al re-guardar). No luches contra ello.

**UIDs y archivos `.uid` (desde 4.4):**

- Escenas/recursos importados guardan su UID en su propio header (`uid="uid://..."`). **No tienen sidecar.**
- Scripts `.gd` y shaders `.gdshader` son texto plano sin sitio para metadata → reciben un **sidecar `player.gd.uid`** cuyo contenido es una sola línea: `uid://...`.
- El mapa `uid:// → res://ruta` vive en `.godot/uid_cache.bin` (binario, NO se commitea). Por eso un UID inventado a mano que no existe en la cache produce warning hasta el reimport.

**Cargar/resolver por UID (sobrevive a movimientos de fichero):**

```gdscript
var scn := load("uid://cecaux1sm7mo0") as PackedScene   # load() acepta uid:// directo
var id := ResourceUID.text_to_id("uid://cecaux1sm7mo0")
if ResourceUID.has_id(id):
    print(ResourceUID.get_id_path(id))                  # -> res://main.tscn
```

### Pitfalls y mensajes de error literales

- **`ext_resource, invalid UID: uid://<x> - using text path instead`** — El `uid://` no está en `uid_cache.bin` (lo inventaste, borraste `.godot/`, o no commiteaste el `.uid`). NO es error duro: el `path=` aún resuelve y solo emite warning. **Fix:** re-guardar la escena en el editor, o `godot --headless --import` para reconstruir la cache, o `Project > Tools > Upgrade Project Files`. Si quieres limpiar a mano, borra el atributo ` uid="..."` roto del `ext_resource` y deja que Godot lo reasigne al guardar.
- **`...invalid UID ... and there's no fallback at set path`** — UID inválido **y** el `path=` también roto (archivo movido). Esto SÍ es error duro: la escena no carga. Restaura el archivo o corrige `path=`.
- **`Parse Error: [ext_resource] referenced non-existent resource` / `Scene file appears to be invalid/corrupt`** — Sección fuera de orden, `id` sin comillas, `format` incorrecto, `ExtResource("X")`/`SubResource("X")` apuntando a un `id` no declarado, `parent=` a nodo inexistente, o literal mal formado (`Transform3D` con nº de floats incorrecto). **Fix:** grep de cada `id="..."` contra cada referencia; verificar 12 floats en `Transform3D`.
- **Autoload "existe pero no carga":** omitir el prefijo `*` en `[autoload]` → singleton deshabilitado → `Identifier "GameState" not declared`. El valor debe ser `Nombre="*res://..."`.
- **`[input]` editado a mano:** los `InputEvent` se serializan como `Object(InputEventKey, "physical_keycode":4194309, ...)` con decenas de campos y keycodes físicos vs lógicos. Extremadamente frágil. **No lo edites a mano**; usa el editor o `InputMap.add_action()` por código en un autoload.
- **`Invalid type in property` al cargar (4.6 específico):** las props de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`) pasaron de `String` a `StringName` (GH-110767). En `.tscn` usa `current_animation = &"walk"`. NO afecta a nombres de track.
- **`ResourceSaver.save` falla con `ERR_CANT_OPEN`:** la carpeta `res://` destino no existe (Godot NO crea dirs). Llama `DirAccess.make_dir_recursive_absolute()` primero. SIEMPRE comprueba `err == OK`.
- **`ResourceUID.get_id_path()` devuelve inválido/-1 en proyecto EXPORTADO** (godot#75617). No dependas de resolver UID→path en runtime empaquetado. `load("uid://...")` suele funcionar empaquetado porque `uid_cache.bin` se incluye en el PCK, pero hay casos de fallo en export/PCK montados (godot#79009, godot#82061: el `uid_cache.bin` de PCKs montados no se fusiona); si exportas y el UID no resuelve, ten un fallback a `res://` o reconstruye la cache. Lo que NO es fiable en export es resolver UID→path con `get_id_path()`.
- **C# NO corre en export web** (renderer Compatibility). Si el target incluye web, escribe el save/load en GDScript.
- **Duplicate UID** (copy-paste de archivos fuera del editor): dos recursos con el mismo `uid://`. No hay autofix; borra el `.uid` de uno y re-guarda, o `ResourceUID.create_id()`.

### Cómo no quedarte atascado

Flujo headless para una IA ciega tras generar/editar archivos:

```bash
# 1. Validar SINTAXIS de un script (NO valida .tscn/.tres)
godot --headless --check-only --script res://src/player.gd

# 2. Reconstruir uid_cache.bin + reimportar (tras clone, mover archivos o UIDs inventados)
godot --headless --import

# 3. Cargar escenas y cazar errores de parseo en el log
godot --headless --quit-after 2 --verbose 2>&1 | grep -iE "error|invalid uid|parse"
```

- **`--check-only` solo valida GDScript, NO escenas.** Las escenas solo se validan al cargarlas: arranca headless y parsea el stderr.
- **Pitfall CI muy documentado:** con `.godot/` ignorado, en un clone fresco los recursos no están importados → `--export-release` falla. El workaround `--headless --editor --quit` NO es fiable. Usa **`--quit-after 2`** (con `--quit` o `--quit-after 1` el import no termina, issue #77508). Corre un paso `--headless --import` dedicado ANTES de exportar.
- **Mover archivos fuera del editor:** mueve SIEMPRE el `.uid` (y el `.import` del asset) junto al archivo. `git mv player.gd nueva/player.gd && git mv player.gd.uid nueva/player.gd.uid`. Olvidar el `.uid` regenera un UID nuevo → todas las refs por UID viejo rotas.
- **VCS:** ignora **toda** la carpeta `.godot/`. **COMMITEA** los `*.uid` (son estado del proyecto, no output; ignorarlos rompe los enlaces escena↔script para todo colaborador) y los `*.import` de assets (contienen el UID estable del asset). `.gitignore` 4.x oficial = básicamente solo `.godot/`. Genera metadata con `Project > Version Control > Generate Version Control Metadata`.

### Addon vs construirlo

- **Generar `.tscn`/`.tres`/`project.godot` a mano: construir.** Es texto determinista; la skill es justamente esto. Pero omite `uid://` inventados y valida con arranque headless.
- **InputMap en `project.godot`: NO a mano.** Usa `InputMap.add_action()` por código o el editor.
- **Regenerar UIDs/cache: usa el engine** (`--headless --import`), no reinventes el parser.
- **Cargar `.tres` desde savegames NO confiables del jugador: usa addon.** `ResourceLoader.load()` ejecuta scripts/sub-recursos embebidos → vector de RCE. Para datos no confiables usa [godot-safe-resource-loader](https://github.com/derkork/godot-safe-resource-loader). Para data interna definida por ti, `ResourceLoader` normal está bien.

**Veredicto ponytail:** el mejor `.tscn` es el que no escribes a mano. Genera por código con `ResourceSaver.save()` (que asigna y persiste el UID por ti) o deja que el editor sea la fuente de verdad; reserva la edición a mano para cambios deterministas (cabeceras, nodos, autoloads) y nunca inventes un `uid://`. Cuando dudes, `godot --headless --import` y parsea el log: es la red de seguridad que evita el atasco.



> **Escalera ponytail:** meta (formato del motor) · **net propio:** no construyes: entiendes .tscn/.tres/uid para no corromperlos.
