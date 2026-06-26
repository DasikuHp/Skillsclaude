## 21. Arranque de proyecto y addons curados

> Contexto verificado (Godot 4.6, released 2026-01-27, mantenimiento ~4.6.x): GDScript 2.0 + C# .NET 8. **Jolt es el solver 3D por defecto en proyectos nuevos.** `.uid` por todas partes desde 4.4; en 4.6 los `.tscn`/`.tres` **ya no escriben `load_steps`** y las referencias externas viven en `uid://`. Renderers: Forward+ / Mobile / Compatibility (web exige Compatibility; **C#/.NET NO exporta a web**). D3D12 es el driver por defecto en Windows en proyectos nuevos.

### El error mental nº1 de una IA que NO ve el editor

El editor de Godot hace cosas **invisibles desde la CLI y el árbol de archivos**, y ahí es donde una IA se atasca. Tres invariantes que debes internalizar antes de cualquier checklist:

1. **`project.godot` a mano no basta.** La carpeta `.godot/` (caché + tabla UID + importados) **no existe hasta el primer arranque que importa**. Una IA que clona un repo y lanza `--export-release` en frío SIEMPRE falla la primera vez.
2. **Operaciones de UI = escrituras de texto plano a `project.godot`.** Autoloads, plugins habilitados, renderer: todo es editable a mano si sabes la sección y la clave exactas (las doy abajo). No necesitas el editor para esto.
3. **Las referencias escena↔script viven en `uid://`, no en rutas.** Gitignorar los `.uid` rompe enlaces de forma silenciosa para los colaboradores.

**Cómo desatascarse sin abrir el editor (canónico):**

```bash
# 1. Importar assets y generar .godot/, *.import, resolver uid:// — en SU PROPIO proceso.
#    NO combinar import con export en la misma invocación.
godot --headless --import --path . --verbose

# 2. Validar que un script compila (parse/typecheck, NO ejecuta el juego)
godot --headless --check-only --script res://autoload/event_bus.gd --path .

# 3. Smoke test: arrancar sin ventana y salir; 0 líneas de error = sano
godot --headless --path . --quit-after 2 2>&1 | grep -Ei "ERROR|invalid UID|Unable to load"
```

`--import`, `--check-only`, `--headless`, `--script`/`-s`, `--export-release`, `--export-debug`, `--verbose`, `--quit-after N` son flags **reales** de la CLI 4.6.

**Trampa de `--check-only` con autoloads (falso positivo que atasca a la IA):** `--check-only` NO conoce los singletons del bloque `[autoload]`. Validar un script que referencia otro autoload (p.ej. `game_state.gd` usa `EventBus.item_picked.connect(...)`) escupe un falso error `Identifier "EventBus" not declared in the current scope` aunque el código sea correcto (GH-78587). Una IA que valida a ciegas creerá que el script está roto. Regla: usa `--check-only` como señal fiable SOLO en scripts sin dependencias de autoload (como `event_bus.gd`). Para los que referencian otros autoloads, valida con un arranque headless completo (`--headless --quit-after 2`) o ignora específicamente los errores `Identifier ... not declared` que apunten a nombres de autoload.

### Checklist accionable (orden estricto — el orden importa más que cualquier addon)

```
[ ] 1. Decide TARGET primero (desktop / web / móvil). Esto fija renderer + lenguaje
       y es casi irreversible a mitad de proyecto. (web ⇒ Compatibility + GDScript, sin C#)
[ ] 2. godot --version  → confirma 4.6.x
[ ] 3. Crea el proyecto con el renderer correcto (§ tabla). En el Project Manager,
       marca "Version Control Metadata: Git" → genera base .gitignore/.gitattributes.
[ ] 4. Arráncalo UNA VEZ para generar .godot/ (editor, o headless --import).
[ ] 5. Corrige .gitignore/.gitattributes (el por defecto NO cubre bien .uid) ANTES del 1er commit.
[ ] 6. git init → primer commit "scaffold" vacío (para poder revertir un addon que rompa el editor).
       Si usarás binarios grandes: git lfs install + commitea .gitattributes ANTES de meter binarios.
[ ] 7. Estructura de carpetas con mkdir (+ .gitkeep). No esperes al editor.
[ ] 8. Autoloads mínimos en [autoload]: EventBus, GameState/Game, SaveManager (3, no 12).
[ ] 9. Instala addons UNO A UNO, commit entre cada uno. Solo los que usas HOY.
[ ] 10. godot --headless --import --path .  (proceso aparte) → genera .uid/.import.
[ ] 11. Commit incluyendo .uid + .import.
[ ] 12. CI: cachea .godot/imported/; import en proceso separado del export; nunca --quit-after 1 para reimport.
```

**Pitfall de orden (LFS):** si metes GLB/audio grandes ANTES de `git lfs track`, quedan en el historial como blobs normales; migrar después requiere `git lfs migrate import --include="*.glb"` (reescribe historia). La doc recomienda **commitear `.gitattributes` antes que el resto**.

### Renderer + lenguaje por target (decisión casi irreversible)

La clave exacta en `project.godot`:

```ini
[rendering]
renderer/rendering_method="forward_plus"          ; "mobile" | "gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

| Target del RPG | `rendering_method` | C#/.NET | Notas 4.6 |
|---|---|---|---|
| Desktop (Win/Linux/Mac) | **`forward_plus`** | Sí | Default recomendado. D3D12 es el driver por defecto en Windows en proyectos nuevos. |
| Móvil (Android/iOS) | **`mobile`** | Sí | Cambiar de `gl_compatibility` a `mobile` **reduce dispositivos Android soportados** (GH-111729). Glow más rápido en 4.6. |
| **Web (browser/itch)** | **`gl_compatibility`** | **NO** | Forward+/Mobile no funcionan en web. **C#/.NET no exporta a web** (GH-70796 abierto). |

Regla: un proyecto Forward+ **no exporta a web**. Si quieres demo web, vas **Compatibility + GDScript en todo el proyecto** o renuncias a la web. El atasco invisible: una IA elige `forward_plus`, exporta a web y obtiene pantalla negra / shaders rotos en runtime, no un error de build claro.

**Jolt (proyecto nuevo):** ya viene activo, confirmable en `project.godot`:

```ini
[physics]
3d/physics_engine="Jolt Physics"
```

Los nodos (`RigidBody3D`, `CharacterBody3D`) son los mismos; cambia el backend de `PhysicsServer3D`. No traslades supuestos exactos de Godot Physics (p.ej. comportamiento de `move_and_slide` en bordes) — Jolt es más determinista y a veces más "rígido".

### `.gitignore` / `.gitattributes` — el atasco silencioso que corrompe el repo entero

No da error inmediato: rompe a los clones/colaboradores siguientes. El error de bulto es copiar un `.gitignore` de Godot 3.x o genérico que incluya `*.import` y/o `*.uid`.

- **`*.uid` ignorados** → cada clon regenera UIDs nuevos → **se rompen TODOS los enlaces `uid://` escena↔script**. La escena abre pero las referencias apuntan a IDs que solo existían en la máquina del autor. **Commitea los `.uid`.**
- **`*.import` ignorados** → cada clon reimporta con defaults; texturas/fuentes pueden desaparecer y los diffs explotan. **Commitea los `.import`.** (El contenido pesado vive en `.godot/imported/`, que SÍ se ignora.)
- **`.godot/` versionado por error** → conflictos de merge constantes en `uid_cache.bin`, `filesystem_cache`. **Ignora `.godot/`** y arregla el reimport con el ciclo headless, no versionando el caché.

**Regla 4.6 de oro: ignora `.godot/`, commitea `*.import` y `*.uid`.** Ver `examples` para los archivos compile-ready.

**Matiz `export_presets.cfg`:** En 3.x/4.0 guardaba credenciales (keystore passwords) → se ignoraba. Desde **4.1 los secretos se separan en `export_credentials.cfg`**. En 4.6: **versiona `export_presets.cfg`** (presets reproducibles para CI), **ignora `export_credentials.cfg`** y nunca commitees keystores Android (`*.keystore`/`*.jks`) — esos van por variables de entorno / secrets del CI. Si tu equipo aún tiene secretos inline en el preset, mantenlo ignorado hasta limpiarlo.

### Autoloads mínimos (no el "cajón de sastre")

La clave exacta en `project.godot` — **el orden de las líneas = orden de inicialización**:

```ini
[autoload]
EventBus="*res://autoload/event_bus.gd"
GameState="*res://autoload/game_state.gd"
SaveManager="*res://autoload/save_manager.gd"
```

El `*` prefijo = habilitado (sin él se registra pero no se carga). Para una IA esto es oro: "subir el botón de Autoload" del foro = **reordenar líneas en este bloque**. No necesitas editor.

Antipatrón clásico: un único `Global.gd` con vida, oro, inventario, diálogo, flags de debug = junk drawer inmantenible. Separa por responsabilidad y comunica por **señales**, no polling. Mínimo viable para un RPG: **3 autoloads, no 12**. Pon `EventBus` (señales puras, cero dependencias) PRIMERO; el resto se comunica vía señales → rompe ciclos.

```gdscript
# autoload/event_bus.gd — bus de señales global, desacopla sistemas
extends Node

signal player_died
signal item_picked(item_id: StringName, amount: int)
signal scene_change_requested(target: String)
```

Reglas que causan crashes/deadlocks reales:
- **NUNCA accedas a otros autoloads en `_init()`** — aún no existen. Usa `_ready()`/`_enter_tree()`. Síntoma: `Cannot call method 'xxx' on a null value` durante el arranque.
- **NUNCA dependencias circulares** entre managers (GameState↔SaveManager) → deadlock de inicialización.
- **`class_name` + autoload del MISMO script** → error `Class "X" hides an autoload singleton`. Usa `class_name` para tipos reusables (`Item`, `Stats`) y autoload para servicios; no ambos en el mismo archivo.

### Estructura de carpetas (híbrida: feature-local + type-global)

La doc oficial sugiere organización **por feature/escena** (recursos exclusivos junto a su escena). Para un RPG, la híbrida gana: entidades concretas feature-local, recursos compartidos por tipo. Ver `examples` para el árbol completo.

Convenciones que evitan bugs reales:
- **snake_case** para archivos/carpetas (excepto scripts C#) → evita el bug de **case-sensitivity**: en Windows/macOS `Player.tscn` y `player.tscn` colisionan; en Linux/CI no. Si una escena referencia `res://Scenes/...` y la carpeta real es `scenes/`, el export en Linux/CI falla con recurso no encontrado.
- **PascalCase** para nombres de nodo (coincide con built-ins).
- Datos como `Resource` tipados (`.tres`) en `data/`, separados de la lógica en `systems/`. `@abstract` (desde 4.5) para clases base (`Item`, `State`, `Ability`) evita instanciar la base por error.

### Addon vs construirlo

| Caso | Recomendación |
|---|---|
| Cámara 3ª persona simple (follow + offset) | **Construir**: `Camera3D` + `SpringArm3D` nativos. Phantom Camera solo si necesitas blends/framing multi-target. |
| Inventario trivial (pocos slots, sin stacking) | **Construir** con `Resource` (`class_name Item`) + `Array[Item]`. GLoot si necesitas grid, constraints, stacking, drag&drop serio. |
| FSM de UN personaje (4-5 estados) | **Construir** un `match state:` o nodos. LimboAI/Beehave cuando hay muchos agentes y árboles reutilizables. |
| Diálogos lineales cortos | **Construir** con `RichTextLabel` + JSON. Dialogic cuando hay branching, retratos, condiciones, localización. |
| Save/load | **Construir** (autoload + `FileAccess`/`ResourceSaver` + tus `Resource`). Ningún addon encaja con tu esquema de datos sin pelear; es ~100 líneas auditables. |
| Testing | **Siempre addon** (GUT/gdUnit4). Nunca escribas tu propio runner. |

Regla: no metas un addon hasta tener un caso de uso real que ya te duele. Cada addon es deuda atada a su soporte de versión de Godot. Para web, evita GDExtension nativo (LimboAI) y C#.

### Lista CURADA de addons 4.6 (repos reales verificados)

Tabla completa con URLs en `examples`. Selección rápida:
- **Diálogos:** Dialogic 2 (`dialogic-godot/dialogic`). Alternativa más ligera: `nathanhoad/godot_dialogue_manager`. Elige uno.
- **Cámara:** Phantom Camera (`ramokz/phantom-camera`) — estilo Cinemachine.
- **IA (BT/FSM):** **LimboAI** (`limbonaut/limboai`, **C++ GDExtension/módulo — necesita binario por plataforma**, soporte 4.6 desde v1.6.0) **vs Beehave** (`bitbrain/beehave`, branch `godot-4.x`, **GDScript puro, sin binario** → mejor para CI/agentes y para web). **No los uses a la vez** (ver pitfall).
- **Inventario:** GLoot (`peter-kish/gloot`, 4.4+ en releases actuales; la entrada AssetLib aún lista 4.2). (El autor es `peter-kish`, NO "peter1745"; Beehave es de `bitbrain`.)
- **Testing:** GUT (`bitwes/Gut`) si es GDScript puro y quieres mínima fricción; **gdUnit4** si tienes C#/mixto o quieres runner de CI + JUnit XML + GitHub Action oficial.

### Pitfalls y mensajes de error literales

**A) Recurso roto tras clonar / cambiar de versión:**
```
ERROR: Cannot get class 'X'.
res://scenes/foo.tscn:NN - Parse Error: [ext_resource] referenced non-existent resource at: uid://...
ERROR: Cannot load script "res://...": invalid UID: uid://xxxxx - using text path instead
```
Fix: `godot --headless --import --path .` (proceso propio) para regenerar la tabla UID. Si persiste, faltaba commitear `.uid`/`.import`.

**B) El proceso headless se cuelga indefinidamente (no error, no exit):**
Causa documentada: tras `git clone` git pone el **mismo mtime a todos los archivos** (GH-100465) y el importador se atasca. También cuelga el export en headless sin carpeta `.godot/` (GH-95287).
Fix: importa en su propio proceso con `--import`; si nunca se abrió, fuerza dos ciclos de tick: `godot --headless --editor --quit-after 2 --path .`. **Nunca `--quit-after 1` para reimport** — aborta a medias (GH-77508). En CI, cachea `.godot/imported/` entre runs.

**C) `load_steps` desaparece en diffs masivos tras abrir en 4.6:**
Al guardar, 4.6 reescribe el descriptor quitando `load_steps=` → diff en CADA escena con dependencias. Es **esperado** (godot-docs #11707). Higiene: `Project > Tools > Upgrade Project Files`, abre/guarda todo en un commit aislado "migrate to 4.6 tscn format" para no contaminar commits de features. Headless no tiene el menú; equivalente: ciclo `--headless --editor --quit-after 2`.

**D) Plugin no carga tras copiarlo:**
```
Unable to load addon script from path: 'res://addons/x/plugin.gd'. This might be due to a code error in that script. Disabling the addon at 'res://addons/x/plugin.cfg' to prevent further errors.
```
Causas reales: (1) no habilitado en `[editor_plugins]`; (2) `plugin.cfg` apunta a un `script=` inexistente; (3) **GDExtension/C++ (LimboAI) sin el binario `.so/.dll` de tu plataforma** → el `.gdextension` no carga; (4) plugin C# sin compilar (`dotnet build`, o borra `.godot/mono`); (5) versión incompatible (LimboAI <1.6.0 rompe en 4.6).
Habilitar headless editando `project.godot`:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/phantom_camera/plugin.cfg", "res://addons/dialogic/plugin.cfg")
```
Al instalar desde AssetLib, importa **solo el directorio `addons/<x>/`** y nada más.

**E) LimboAI + Beehave juntos = colisión de clases:** ambos registran su propia clase `Blackboard` → error de `class_name` duplicado al cargar (limboai#72, beehave#322). **Elige uno.**

**F) Shader heredado de pre-4 que no compila:**
```
Use of reserved keyword: 'SCREEN_TEXTURE'   (o: Use of undeclared identifier 'SCREEN_TEXTURE')
```
Fix 4.x: built-ins `SCREEN_TEXTURE`/`DEPTH_TEXTURE` eliminados → uniforms con hint:
```glsl
uniform sampler2D screen_tex : hint_screen_texture;
uniform sampler2D depth_tex  : hint_depth_texture;
```

**G) AnimationPlayer en 4.6 (GH-110767):** las **propiedades de nombre de animación** (`current_animation`, `assigned_animation`, `autoplay`, señal `current_animation_changed(name: StringName)`, `get_queue() -> StringName[]`) pasaron de `String` a `StringName`. **NO afecta nombres de track.** Asignar `anim.assigned_animation = "walk"` auto-castea, pero comparaciones estrictas `==` con tipos mezclados o serialización antigua fallan, con `Animation not found: 'animation_name'`. Fix: usa literales `&"walk"` (StringName) al asignar/comparar estas props.

**H) C#/.NET a web no soportado (GH-70796):** el preset falla o el `.wasm` no embebe el runtime .NET. Fix: para web usa Compatibility + **GDScript**.

### Cómo no quedarte atascado

Comandos que una IA SÍ puede correr sin ver el editor:

```bash
# Validar sintaxis GDScript 2.0 de un script SIN dependencias de autoload.
# OJO: --check-only no resuelve singletons [autoload] → un script que use
# otro autoload (EventBus, GameState...) dará un FALSO "Identifier ... not
# declared" (GH-78587). Para esos, valida con --quit-after 2, no --check-only.
godot --headless --check-only --script res://autoload/event_bus.gd --path .

# Confirmar que .uid/.import están trackeados (deben devolver resultados)
git ls-files '*.uid' '*.import'

# Confirmar que .godot/ está ignorado y *.uid / *.import NO
git status --ignored

# Salud general: 0 líneas de salida = sano
godot --headless --path . --quit-after 2 2>&1 | grep -Ei "ERROR|invalid UID|Unable to load"
```

Nunca asumas que `árbol de archivos == estado del editor`. Tras tocar cualquier cosa a ciegas: `--import` (proceso propio) + `--check-only`.

**Veredicto ponytail:** el mejor addon es el que no instalas. Decide target/renderer/lenguaje primero (irreversible), escribe `.gitignore`/`.gitattributes` correctos antes del primer commit (commitea `.uid` y `.import`, ignora `.godot/`), y monta solo 3 autoloads (`EventBus`, `GameState`, `SaveManager`) comunicados por señales. Para cámara, inventario simple, FSM de un personaje y save/load: nodos nativos + `Resource`. Reserva addons (Dialogic, Phantom Camera, LimboAI/Beehave, GLoot, GUT/gdUnit4) para cuando el dolor sea real, e instálalos uno a uno con commit entre cada uno. Y recuerda el invariante que tumba a las IAs headless: `.godot/` no existe hasta el primer import — importa en proceso propio antes de exportar, nunca con `--quit-after 1`.



> **Escalera ponytail:** rung 1+4 (estructura mínima) · **net propio:** 3 autoloads y estructura de carpetas; el resto es YAGNI hasta que duela.
