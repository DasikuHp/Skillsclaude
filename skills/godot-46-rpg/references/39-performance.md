## 39. Performance (jun 2026)

Foco consolidado tras debate MAD. La base factual del Architect sobre Godot 4.6 esta verificada; el Critic aporto correcciones obligatorias que SE INCORPORAN: (1) Summer NO tiene tools de profiling -> medicion solo por CLI/build; (2) el lazo "auto-correctivo" se degrada a diagnostica-propone-NO-aplica (auto-aplicar fixes viola ponytail y rompe gameplay); (3) presupuesto por FRAME-TIME por subsistema, no draw calls (semi-irrelevantes en Forward+/Vulkan, solo importan en web/Compatibility); (4) anadir los problemas que de verdad matan un RPG 3D (hitches de carga/instancia, navegacion, sombras, save/load); (5) ObjectDB Profiler es VISUAL no headless; (6) renderer/FSR por deteccion de capacidad, no hardcode; (7) perf-warnings en canal propio, fuera de errors.json; (8) cruce perf<->accesibilidad real = toggles reduce-motion/desactivar upscaling temporal.

Filosofia rectora PONYTAIL: reusar lo nativo de 4.6 (que en perf ya es de primera linea) antes de inventar arquitectura. Lazy = no construir harness de benchmark ni recompilar para Tracy si los monitores integrados bastan; no optimizar lo que no excede presupuesto (no premature optimization). NOT negligent = nunca aprobar numeros medidos en editor, nunca ignorar crecimiento de Orphan Nodes, nunca enviar web en renderer no soportado, nunca recortar validacion/errores/seguridad/accesibilidad para ganar fps.

### Estado jun-2026

Tools, motores, modelos y tecnicas VIABLES AHORA:

- Profiling sin recompilar (la via por defecto, ponytail): profiler integrado + clase `Performance`. Monitores clave scriptables y headless: `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `OBJECT_ORPHAN_NODE_COUNT`, `OBJECT_COUNT`, `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`, `TIME_FPS`. Docs: https://docs.godotengine.org/en/stable/classes/class_performance.html y https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html
- ObjectDB Profiler (nuevo en 4.6): pestana del Debugger que captura snapshots de objetos vivos y COMPARA dos snapshots (creado/destruido/huerfano). CRITICO en RPG por spawn/despawn masivo. LIMITE VERIFICADO: es herramienta VISUAL/interactiva del editor, NO scriptable/headless. Para el gate automatizado se usa el monitor `OBJECT_ORPHAN_NODE_COUNT`; el snapshot-diff es manual. Doc: https://docs.godotengine.org/en/latest/tutorials/scripting/debug/objectdb_profiler.html
- Tracing profilers (Tracy / Perfetto / Instruments): flame-graph de GDScript/C#/GDExtension, muy por encima del integrado para hotspots reales. COSTE/PITFALL: requieren recompilar el engine; caveats con GDExtension DLLs. Usar SOLO cuando el integrado ya senalo un hotspot que necesita flame-graph. Release: https://godotengine.org/releases/4.6/ · Guia 2026: https://dev.to/ziva/how-to-profile-gdscript-performance-in-godot-4-a-2026-guide-16jn · PR soporte: https://github.com/godotengine/godot/pull/113279 · Profiler instrumentado: https://github.com/AndreaCatania/godot_tracy
- REGLA DE ORO (ancla del foco, doc oficial explicita): "for accurate performance numbers, profile an exported build." Los numeros de F6 dentro del editor NO son los del jugador (overhead por frame del editor). Veredicto de perf SOLO en build exportado. Esto aplica tambien al MCP en editor.
- Rendering nativo: Visibility Ranges/HLOD con MeshInstance3D y MultiMeshInstance3D (https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html), Mesh LOD automatico (https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html). PITFALL DURO VERIFICADO: el bake de occlusion culling SOLO considera MeshInstance3D; MultiMeshInstance3D, GPUParticles3D, CPUParticles3D y CSG NO entran -> decision de diseno consciente (ubicar vegetacion/multitud MultiMesh donde la oclusion no sea critica). Doc: https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/occlusion_culling.rst
- Fisicas: Jolt es el motor 3D por defecto en 4.6, listo para produccion. Para RPG 3D, Jolt es el default; GodotPhysics solo si se necesita determinismo especifico.
- Upscaling: FSR 2.2 integrado. SOLO Forward+/Mobile, NO Compatibility. PITFALLS: en GPU lenta FSR2 cuesta mas que bilinear/FSR1; a resolucion nativa FSR2 es mas caro que TAA nativo (usar solo con headroom de GPU); SMAA+FSR2 rompe el upscaling (borroso). FSR3 frame-gen NO existe (solo propuestas abiertas #8768 y #14768). Docs: https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html · Pitfalls: https://github.com/godotengine/godot/issues/111650 · Propuesta: https://github.com/godotengine/godot-proposals/issues/8768
- Hitches de carga / streaming de mundo (EL problema de perf percibido en RPG, anadido por correccion del Critic): `ResourceLoader.load_threaded_request()` con `use_sub_threads=true` + type hint + `load_threaded_get_status()` por frame -> evita el frame-time spike al instanciar pueblos/mazmorras. PITFALL VERIFICADO: el background loading NO funciona en export web (issue #109914), y puede crashear con multiples escenas complejas (issue #111202). Docs: https://docs.godotengine.org/en/latest/tutorials/io/background_loading.html · Web: https://github.com/godotengine/godot/issues/109914 · Crash multi-escena: https://github.com/godotengine/godot/issues/111202
- Web: Forward+/Mobile NO soportados en web; Compatibility es el recomendado HOY. WebGPU (habilitaria Mobile renderer/compute en navegador) en desarrollo, NO estable -> NO prometer alta fidelidad en web. CRITERIO DE CADUCIDAD: re-evaluar cuando WebGPU sea estable; por eso la skill detecta capacidad del target en tiempo de ejecucion, no hardcodea. Export web: https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html · Guia 2026: https://best-games.io/blog/godot-web-export-optimization-guide
- GDExtension para hot-loops: C++ oficial (https://dev.to/gustavolr548/programming-with-gdextension-high-performance-c-in-godot-4-part-1-3c19) o godot-rust/gdext type-safe (https://github.com/godot-rust/gdext). SOLO tras prueba de profiler, nunca por intuicion. PITFALL: gdext puede crashear en hot-reload (https://github.com/godotengine/godot/issues/115496).
- MCP: Summer Engine (MIT, localhost:6550 stdio, 44 tools: summer_add_node, summer_get_debugger_errors/warnings, summer_get_console, summer_play/stop, generacion de assets, etc.) y Godot AI (HTTP). CORRECCION VERIFICADA DEL CRITIC: Summer NO expone NINGUNA tool de profiling/frame-timing/FPS. El profiling-por-MCP existe en otros productos (Godot MCP Pro de pago), NO en Summer. Repo Summer: https://github.com/SummerEngine/summer-engine-agent · Guia MCP: https://www.summerengine.com/blog/godot-mcp-servers-guide

### Simbiosis con el flujo de la skill

Pasos accionables (dispatcher, lazo, MCP, commands, hooks):

1. Dispatcher (SKILL.md): tema -> `references/39_performance.md` para `performance|profiling|fps|lag|hitch|stutter|draw calls|lod|jolt|fsr|multimesh|hot loop|nav|sombras|load|streaming`. Regla en dispatcher: toda propuesta de optimizacion dispara primero el sub-workflow de profiling-en-build-exportado; nunca medir en editor.

2. Lazo de verificacion (verify_loop.sh / validate_all.gd) -> degradado de "auto-correctivo" a PERF REPORT no-bloqueante (correccion central del Critic, alineada con ponytail):
   - Export build headless del target activo.
   - Ejecutar escena de prueba (manual o on-rails simple; NO construir harness de QA enterprise).
   - Capturar via clase `Performance`: frame time p50/p99, `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, draw calls, `OBJECT_ORPHAN_NODE_COUNT`, `OBJECT_COUNT`, VRAM.
   - Comparar contra presupuesto FRAME-TIME por subsistema (tabla abajo). Si excede, escribir reporte PRIORIZADO coste/beneficio con metrica y sintoma a un canal de perf propio.
   - PARAR. Claude DIAGNOSTICA y PROPONE; el dev decide. NO auto-aplica fixes (performance no es causal 1:1; aplicar MultiMesh por draw calls altos puede romper colision/scripts por entidad).
   - Si `OBJECT_ORPHAN_NODE_COUNT` crece entre arranque y fin del benchmark -> senal de fuga (bloqueante; confirmar fuga concreta con ObjectDB compare MANUAL en editor).

3. MCP Summer / Godot AI: detectar backend y leer contrato real. NINGUNO ofrece profiling fiable de runtime para el veredicto -> toda medicion de perf va por CLI headless + clase `Performance` sobre build exportado. Summer se usa para edicion/diagnostico (`summer_get_debugger_warnings`, `summer_get_debugger_errors`, `summer_get_console`) como senal complementaria, no como medidor de perf. NO crear sub-accion `/godot-mcp profile`.

4. Commands: `/godot-verify --perf [desktop|mobile|web]` dispara el perf report; nuevo `/godot-perf` = one-shot diagnostica y propone fixes priorizadas (no aplica); `/godot-flow` inserta checkpoint de presupuesto antes de "feature done".

5. Hooks (PostToolUse): tras editar `.gd`, ademas de validar sintaxis, lint de hot-path SOLO patrones de ALTA confianza para evitar fatiga de alertas: `get_node` con path constante cacheable via `@onready`, concatenacion de `String` en loop dentro de `_process`/`_physics_process`. Escribir a canal PROPIO `perf_warnings.json` (NO `errors.json`, para no contaminar errores de compilacion). NO marcar `instantiate()`/`get_node` genericos (falsos positivos).

6. GameSoul.md (references/29): escribir seccion "Performance Budget" (frame-time por subsistema, ajustable) para que toda skill la respete.

### Como se adapta Claude

Decisiones firmes:
- Renderer por target: Forward+ (desktop), Mobile (movil), Compatibility (web obligatorio HOY) -> por DETECCION del preset de export, no hardcode, para sobrevivir a WebGPU.
- Jolt por defecto en 3D.
- FSR2 solo si renderer != Compatibility Y hay headroom de GPU; ofrecer toggle de usuario.
- HLOD via Visibility Ranges + MultiMesh para multitudes/vegetacion, con decision consciente del caveat de occlusion bake.
- Mover a GDExtension SOLO un hot-loop probado por profiler.
- Orden de prioridad RPG (reordenado por el Critic): 1) hitches de carga/instancia (threaded load + pooling) -> 2) navegacion/fisicas con muchos agentes -> 3) sombras/luces dinamicas -> 4) draw calls (solo relevante en web/Compatibility) -> 5) upscaling. Empezar por lo que mata RPGs (spikes), no por rendering estacionario glamuroso.

Tools que usa: profiler integrado + clase `Performance` para el report automatico (sin recompilar); ObjectDB compare manual para confirmar fugas; Tracy/Perfetto solo cuando el integrado senala un hotspot que pide flame-graph (consciente del coste de recompilar). Summer solo edicion/diagnostico.

Que verifica antes de declarar done: build EXPORTADO (no editor); frame-time por subsistema y p99 dentro de presupuesto; sin crecimiento de Orphan Nodes; VRAM en presupuesto; que la fix no rompio validacion/errores/accesibilidad (regresion via validate_all.gd).

Ponytail: primero MultiMesh/LOD/Visibility Ranges/occlusion/Jolt/threaded-load nativos; FSR2 nativo antes que shaders custom; GDExtension como ultimo recurso medido. Lazy = no recompilar para Tracy ni construir harness si los monitores bastan. NOT negligent = nunca aprobar perf de editor, nunca ignorar Orphan Nodes, nunca web en Forward+, nunca FSR2 en Compatibility, nunca GDExtension sin prueba de profiler, nunca recortar accesibilidad por fps.

### Acciones concretas

- Crear `references/39_performance.md` con: orden de prioridad RPG; tabla de presupuesto frame-time por subsistema; tabla sintoma->diagnostico (no auto-remedio); caveats verificados.
- Tabla PRESUPUESTO FRAME-TIME por subsistema (renderer-agnostico, accionable; valores de partida ajustables por GameSoul, NO presentar como verdad absoluta):

  | Subsistema (monitor) | Desktop 60fps (16.6ms total) | Movil 30fps (33.3ms) | Web 60fps (16.6ms) |
  |---|---|---|---|
  | Scripts (TIME_PROCESS) | <= 4ms | <= 8ms | <= 4ms |
  | Fisicas (TIME_PHYSICS_PROCESS) | <= 4ms | <= 8ms | <= 4ms |
  | Render CPU+GPU (resto) | <= 8ms | <= 16ms | <= 8ms |
  | Orphan Nodes (crecimiento) | 0 | 0 | 0 |
  | FSR2 | si, con headroom | si, con headroom | NO disponible |
  | Texturas | nativas | ETC2 | ETC2/S3TC + Basis Universal |
  | Draw calls (solo gate en web) | no-gate (informativo) | informativo | gate ~<=500 |
  | Threaded load | si | si | NO (issue #109914) -> precarga/loading screen |

- Tabla SINTOMA -> DIAGNOSTICO (alimenta el report; Claude PROPONE, no aplica):
  - Spike de frame-time al entrar a zona -> hitch de instancia/carga: usar `load_threaded_request` + pooling; en web precargar.
  - TIME_PHYSICS alto -> muchos cuerpos activos / nav: Jolt + islas dormidas, reducir agentes activos, presupuestar NavigationServer.
  - Render alto con headroom GPU -> FSR2 (no en Compatibility) o reducir sombras/luces dinamicas (coste #1 GPU en RPG, no draw calls).
  - TIME_PROCESS alto sostenido -> hotspot GDScript: cachear `@onready`, poolear; si persiste y lo confirma Tracy, GDExtension.
  - Orphan Nodes crece -> `queue_free` faltante / senales no desconectadas: confirmar con ObjectDB compare manual.
  - Draw calls altos (solo web) -> MultiMesh/batching/Visibility Ranges.
- Cambios de archivos: SKILL.md (dispatcher + regla build exportado); verify_loop.sh/validate_all.gd (perf report no-bloqueante); hooks/PostToolUse (lint alta-confianza -> perf_warnings.json); commands (/godot-verify --perf, /godot-perf); agents/godot-reviewer (checklist perf); references/30 (Summer sin profiling, perf por CLI); references/29 (Performance Budget en GameSoul.md).

### Pitfalls y limite lazy-not-negligent

Pitfalls verificados (no inventados):
1. Medir en editor != jugador. Veredicto solo en build exportado (doc oficial explicita).
2. Tracy requiere recompilar el engine; caveats con GDExtension DLLs.
3. Occlusion bake ignora MultiMesh/particulas/CSG -> decision de diseno obligada.
4. FSR2: no en Compatibility; SMAA+FSR2 = borroso; coste > bilinear en GPU lenta; nativo > TAA nativo. FSR3 no existe.
5. Web: Forward+/Mobile no soportados; WebGPU no estable; background threaded loading NO funciona en web (issue #109914). No prometer alta fidelidad en web.
6. gdext puede crashear en hot-reload; load_threaded_request puede crashear con multiples escenas complejas (issue #111202).
7. Summer NO tiene profiling tools -> no enrutar medicion por Summer; medir por CLI/build. (correccion verificada del Critic; descartado el "contrato de capability profiling" del Architect por ser ficcion).
8. Draw calls como gate global es la metrica equivocada en Forward+/Vulkan (importa fill-rate/shaders/sombras); solo es gate en web/Compatibility. (correccion del Critic).
9. ObjectDB Profiler es visual/no-headless; el gate usa monitores Performance, no el snapshot-diff. (correccion del Critic).
10. Auto-aplicar fixes de perf es peligroso (causalidad no 1:1) y anti-ponytail; diagnosticar y proponer, no aplicar. (correccion del Critic).

Limite lazy-not-negligent:
- Lazy permitido: reusar nativo (MultiMesh/LOD/Jolt/FSR2/threaded-load); no recompilar para Tracy si el integrado basta; no construir harness de benchmark enterprise; no optimizar lo que no excede presupuesto.
- Negligente PROHIBIDO: aprobar numeros de editor; saltarse la verificacion de Orphan Nodes; exportar web en renderer no soportado; FSR2 en Compatibility; GDExtension sin prueba de profiler; auto-aplicar fixes que rompan gameplay; contaminar errors.json con perf-noise; recortar validacion/errores/seguridad/accesibilidad por fps.
- Cruce perf<->accesibilidad (anadido por el Critic): FSR2/TAA/motion blur causan mareo; la accesibilidad EXIGE toggles de reduce-motion y opcion de desactivar upscaling temporal. La perf nunca justifica romper accesibilidad.

### Fuentes

- https://godotengine.org/releases/4.6/
- https://docs.godotengine.org/en/stable/classes/class_performance.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html
- https://docs.godotengine.org/en/latest/tutorials/scripting/debug/objectdb_profiler.html
- https://dev.to/ziva/how-to-profile-gdscript-performance-in-godot-4-a-2026-guide-16jn
- https://github.com/godotengine/godot/pull/113279
- https://github.com/AndreaCatania/godot_tracy
- https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html
- https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/occlusion_culling.rst
- https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html
- https://github.com/godotengine/godot/issues/111650
- https://github.com/godotengine/godot-proposals/issues/8768
- https://docs.godotengine.org/en/latest/tutorials/io/background_loading.html
- https://github.com/godotengine/godot/issues/109914
- https://github.com/godotengine/godot/issues/111202
- https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html
- https://best-games.io/blog/godot-web-export-optimization-guide
- https://dev.to/gustavolr548/programming-with-gdextension-high-performance-c-in-godot-4-part-1-3c19
- https://github.com/godot-rust/gdext
- https://github.com/godotengine/godot/issues/115496
- https://github.com/SummerEngine/summer-engine-agent
- https://www.summerengine.com/blog/godot-mcp-servers-guide
