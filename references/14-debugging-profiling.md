## 14. Depuración y profiling

Un RPG 3D es el peor caso para depurar: cientos de nodos vivos, cambios de escena constantes (overworld ↔ combate ↔ menús), instanciado masivo de enemigos/loot/proyectiles y un autoload que sobrevive a todo. Aquí se acumulan los leaks y los lag spikes. Godot 4.6 trae herramientas integradas potentes (ObjectDB Profiler, Visual Profiler, Tracy/Perfetto/Instruments oficiales, botón Step Out); el error que atasca a una IA es ignorarlas y "tirar prints".

### Enfoque nativo recomendado

No construyas un sistema de depuración propio. En 4.6 todo lo que necesitas ya viene integrado. Pirámide canónica, en orden:

1. **Errores/warnings del panel Debugger** (pestaña *Errors*): clic en el error salta a la línea con stack expandible.
2. **Breakpoints + stepping** (F9 / palabra clave `breakpoint`), ahora con **Step Out** (nuevo en 4.6).
3. **Backtraces programáticos** (`print_stack`, `get_stack`, `print_debug`).
4. **Monitors + Profiler + Visual Profiler** para lag.
5. **ObjectDB Profiler** (nuevo en 4.6) para leaks / orphan nodes.
6. **Tracy / Perfetto / Apple Instruments** (oficiales en 4.6) para microsegundos por hilo, solo cuando el cuello de botella está en el engine.

**Decisión rápida — cuelgue vs lag (son dos flujos distintos):**

- **HANG (freeze total):** casi siempre bucle infinito o recursión de señales (A emite B, B reemite A). El stepping no ayuda si ya colgó. Corre desde terminal con `godot --verbose --path /ruta` y mira la última línea antes del freeze; pon un `breakpoint` antes de la sección sospechosa y haz Step Over; mete un contador guardia (`assert(_guard < 100000, ...)`).
- **LAG (FPS cae, responde):** Monitors → ¿sube *memory*, *nodes*, *orphans*, *draw calls*? Luego Visual Profiler para saber si es **CPU (izquierda) o GPU (derecha)**, y solo entonces el Profiler integrado ordenado por **Self Time** (no Total Time).

### El enemigo #1 del RPG: orphan nodes y ciclos RefCounted

El leak más común no es C++ ni texturas: es `remove_child()` sin `queue_free()`, o un nodo instanciado que nunca entra al árbol. Diferencia clave que origina la mayoría de leaks:

- `queue_free()` saca del árbol Y libera al final del frame.
- `remove_child()` **solo desvincula**; el nodo sigue vivo como orphan hasta que lo `free()`/`queue_free()` o lo reparentes. Pooling con `remove_child` es correcto **solo si** conservas la referencia para reusarlo.
- **Regla de oro:** nunca `extends Node` en algo que no metes en el SceneTree. Una clase de datos/utilidad debe ser `extends RefCounted` (se libera por conteo) o `Resource`.
- **Ciclo RefCounted** (A→B→A): el refcount nunca llega a 0; `queue_free` no aplica. Rómpelo con `weakref()` en una de las direcciones.

**Flujo 4.6 (ObjectDB Profiler, pestaña nueva en el panel Debugger):** toma un *snapshot* en el overworld → entra y sal de combate varias veces → toma otro snapshot → **diff**. Lo añadido sale en **verde**, lo eliminado en **rojo**; los orphans se agrupan aparte (no cuelgan de la raíz). Esto te da la **clase exacta** que no se libera. Vistas: *Nodes* (árbol + huérfanos), *RefCounted* (resalta ciclos), *Summary* (marca problemas). Complemento programático: `print_orphan_nodes()`. Al cerrar el juego, `ERROR: ObjectDB instances leaked at exit (run with --verbose for details)` confirma un leak; relanza con `--verbose` para el stack de creación.

### GDScript

Ver ejemplo completo `debug_tools.gd` (custom monitors, backtraces, asserts, toggles de visualización, chequeo de leaks).

### C# (.NET 8)

Ver ejemplo `DebugTools.cs`. Nota: **web NO tiene C#** (renderer Compatibility); si exportas a web, todo el debug en C# desaparece, usa GDScript. `assert` de GDScript no existe en C#: usa `System.Diagnostics.Debug.Assert` (también se elimina en build Release, mismo riesgo de side-effects).

### Pitfalls y mensajes de error literales

- **`assert()` se strippea COMPLETO en release.** Si metes lógica con efectos secundarios (`assert(spawn_enemy())`), funciona en el editor y **el enemigo nunca aparece en el export**. Además `assert` es palabra clave, no función: no la uses como expresión (`var a = assert(...)` → error de parser) y el segundo argumento debe ser un String constante.
- **`get_stack()` / `print_stack()` / `print_debug()` devuelven vacío o no hacen nada sin servidor de debug.** No funcionan en release, ni en build debug exportada no conectada, ni desde un `Thread`. Para release/crash reports activa `ProjectSettings → debug/settings/gdscript/always_track_call_stacks` (+ `Engine.capture_script_backtraces()`). Salvedad verificada (godot#106484): en exports release los números de línea del backtrace son incorrectos (apuntan a la firma de la función) — usa `function`, no `line`.
- **Firma OBSOLETA de Godot 3 en `add_custom_monitor`** — el error que más comete una IA: `add_custom_monitor("Player Health", self, "_get_health")`. En Godot 4 es `(id: StringName, callable: Callable, arguments := [])`. La vieja produce `Invalid type in function 'add_custom_monitor': argument 2 should be Callable`. Pasa un Callable: `_get_health` en GDScript, `new Callable(this, MethodName.X)` o `Callable.From(...)` en C#.
- **`Custom monitor 'X' already exists.`** Re-registrar el mismo id (autoload que sobrevive, `_ready()` que corre dos veces tras reparenting). Protégete con `if not Performance.has_custom_monitor(id):` y limpia en `_exit_tree()`.
- **El callable de un monitor debe devolver número >= 0.** La doc lo exige explícitamente: ha de devolver un entero o flotante cero o positivo; devolver String/null produce un valor inválido y rompe la gráfica en silencio. No hagas trabajo pesado dentro: se llama periódicamente (observer effect).
- **"Mis breakpoints no pausan."** Causas en orden: *Skip Breakpoints* activado (botón pegado entre sesiones); corriendo en export release / sin conexión al editor; breakpoint en un `Thread` secundario; línea no ejecutable. Verifica sesión activa en el panel Debugger; lanza con F5 **desde el editor Godot**, no desde VSCode (el Remote scene tree no aparece vía VSCode — godot-vscode-plugin#567).
- **Profiler vs Visual Profiler (error de categoría).** Profiler = tiempo CPU por función/script. Visual Profiler = coste del **renderer por frame** (GPU/render passes). Usar el equivocado persigue el cuello de botella incorrecto. Olvidar pulsar **Start** → "el profiler está vacío" (no graba por defecto).
- **`debug_collisions_hint` por código en runtime a menudo NO dibuja** si el menú del editor estaba OFF (godot#64353): el menú y la propiedad chocan. Usa **uno solo**: para depuración manual, el menú *Debug → Visible Collision Shapes*; para builds de debug, setea la propiedad **antes del primer frame físico** (togglear en caliente no re-genera shapes ya creados). En exports, `CollisionPolygon2D` solo muestra contorno (godot#99935 — no es tu bug). Desactiva estas visualizaciones antes de medir frame time.
- **"El Visual Profiler muestra tiempos CPU raros / Process tarda muchísimo sin justificación"** (godot#97473, #81435): a veces es tiempo de sincronización del frame contabilizado dentro de Process, o tiempos CPU del Visual Profiler poco fiables. Confirma con Self Time y un monitor de FPS. En **macOS/Metal el frametime GPU integrado está roto** (godot#102968): usa Apple Instruments.
- **"Solo es lento en debug."** El debugger remoto añade overhead por nodo/llamada (foro "DEBUG in 4.5 is unusable"). **Antes de optimizar, mide siempre con un export `template_release`.** Si el spike desaparece, era el debugger, no tu juego.
- **Spike de "primera vez"** (primer disparo / primer enemigo / primera escena de combate): carga lazy de recursos y **compilación de shaders**. Fix: `preload()` y shader pre-warming (instancia el material una vez fuera de cámara en la pantalla de carga).
- **Tracy no conecta:** requiere recompilar Godot con soporte de profiling (`tracy_enable=yes`), no sirve el binario oficial de release; la versión del viewer debe coincidir con el build. Sin `-fno-omit-frame-pointer -fno-inline -ggdb3` el callstack sale inútil.

### Cómo no quedarte atascado (checklist de decisión)

1. ¿Estás en **debug build conectada al editor** (F5)? Si no, breakpoints/`get_stack`/`print_stack`/`print_debug` no van.
2. ¿`Skip Breakpoints` activado por accidente?
3. ¿Solo pasa en debug? → mide en export release antes de tocar código.
4. Lag → Visual Profiler: ¿CPU (izq) o GPU (der)? Luego Profiler por **Self Time**.
5. ¿Usaste la firma **Callable** de `add_custom_monitor` (no objeto+string de Godot 3)? ¿El callable devuelve número >= 0? ¿Pulsaste **Start** en el Profiler?
6. Memoria crece → Monitors (orphan/object count) → **ObjectDB snapshot diff** → arregla `queue_free`/ciclos RefCounted. Un orphan NO aparece en el Remote scene tree (no está en el árbol) — míralo en el ObjectDB Profiler. No confíes en `get_orphan_node_ids()` (incompleto, godot#114854).
7. Cuelgue → `--verbose` + buscar bucle/señal recursiva + `breakpoint`.
8. ¿`assert()` con side-effects (se elimina en release) o usado como expresión?
9. Web: sin C#, Compatibility, conexión remota frágil → `--verbose` + consola del navegador.

### Addon vs construirlo

- **No construyas** un sistema de profiling propio: ObjectDB Profiler, Visual Profiler, Monitors y soporte Tracy/Perfetto/Instruments ya vienen integrados en 4.6. Construir era justificado en 3.x; en 4.6 es reinventar la rueda.
- **Sí construye tus custom monitors** con `Performance.add_custom_monitor` (enemigos vivos, tamaño del pool de proyectiles, entradas del caché de pathfinding, items de inventario): es API oficial, barato, se integra en la pestaña Monitors, y te permite **correlacionar el spike con tu dominio** ("el spike coincide con 120 enemigos vivos → spawner sin tope"). Instrúmentalo desde el día 1.
- **Addon recomendado** solo para HUD in-game de métricas en builds de QA sin editor conectado: **godot-debug-menu** (asset library #1902).
- **Tracy** solo cuando el integrado dice "está en render/física" pero no sabes qué función, o necesitas resolución por hilo (Jolt corre física en hilos). En **macOS**, Apple Instruments para GPU.

**Veredicto ponytail:** el mejor sistema de depuración es el que no escribes. 4.6 ya trae ObjectDB Profiler con snapshot diff, Visual Profiler CPU/GPU, Step Out y Tracy/Perfetto/Instruments oficiales — todo nativo. Lo único que vale la pena escribir tú son cuatro líneas de `add_custom_monitor` por cada métrica de tu RPG, porque el engine mide el engine y tú tienes que medir tu juego. Antes de optimizar nada, verifica que el problema no sea solo el overhead del debugger: exporta en release y vuelve a medir.



> **Escalera ponytail:** rung 4 (debugger/monitores nativos) · **net propio:** 0 código de gameplay: usas el debugger y monitores del motor.
