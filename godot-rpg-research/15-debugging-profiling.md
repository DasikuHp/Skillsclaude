## Adjudicación del debate

Las tres lentes coincidieron en un grado inusualmente alto; no hubo contradicciones de fondo, solo diferencias de énfasis y un par de detalles a verificar. Resumen de dónde difirieron y cómo lo resolví:

- **Firma de `add_custom_monitor`.** Docs y escéptico dieron la firma exacta `(id: StringName, callable: Callable, arguments := [])`; el escéptico añadió el matiz de mayor valor anti-stuck: el error real es escribir la firma de Godot 3 (objeto+string) y el mensaje literal que produce. Lo verifiqué vía WebSearch contra los docs oficiales (`custom_performance_monitors`): confirmado, el callable debe devolver entero/float cero-o-positivo. Mantuve el énfasis del escéptico por ser el punto más anti-stuck.

- **ObjectDB Profiler (estrella de 4.6).** Las tres lentes lo destacaron. Verifiqué vía WebSearch: confirmado snapshot + diff (verde=añadido, rojo=eliminado), vistas Nodes/RefCounted/Summary, orphans agrupados aparte (PR #97210, docs stable). Lo coloqué como herramienta principal anti-leak, sustituyendo el conteo manual que mencionaba el veterano (que dejé solo como complemento programático con `print_orphan_nodes()`).

- **`get_stack` líneas incorrectas en release.** Solo docs lo señaló (godot#106484) con la consecuencia práctica (usar `function`, no `line`). Lo incorporé porque es verificable y evita un atasco real.

- **Bugs de plataforma (Metal/macOS GPU profiling roto #102968, Visual Profiler CPU times #97473, lag spikes en debug #78754).** Aportados por field y skeptic; docs no los cubrió. Los mantuve porque son verificables vía issues reales y de alto valor: evitan que una IA persiga un fantasma. Subordiné el consejo "mide en release primero" como regla destacada.

- **Step Out (nuevo 4.6), backtraces en release (`always_track_call_stacks`), assert strippeado, Profiler vs Visual Profiler, `debug_collisions_hint` vs menú (#64353):** consenso de las tres lentes, mantenidos.

- **Descartes / cautela:** el snippet C# del escéptico `var frames = GD.Print(Engine.GetMainLoop())` para "get_stack" era incorrecto/confuso (no es un equivalente); lo eliminé y usé `System.Diagnostics.StackTrace` (del dossier docs) que sí compila. El bug del cursor en Step Into (#109904) es de 4.4.x y sin confirmar en 4.6.3; lo omití de la sección final para no afirmar algo no verificado. El flag de compilación de Tracy y los macros `FrameMark`/`ZoneScoped` los reduje a una nota de pitfall (nicho, fuera del flujo principal de un RPG en GDScript).

- **Prioridad docs 4.6:** ante cualquier duda prioricé lo verificable en docs.godotengine.org y PRs/issues reales. Verifiqué dos puntos contestados (ObjectDB diff, firma del monitor) con WebSearch en vivo; ambos confirmados.

## Fuentes

- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/objectdb_profiler.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/custom_performance_monitors.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html
- https://docs.godotengine.org/en/stable/classes/class_performance.html
- https://docs.godotengine.org/en/4.6/classes/class_@gdscript.html
- https://docs.godotengine.org/en/stable/classes/class_scriptbacktrace.html
- https://docs.godotengine.org/en/4.6/engine_details/development/profiling/tracy.html
- https://docs.godotengine.org/en/stable/engine_details/development/profiling/instruments.html
- https://github.com/godotengine/godot/pull/97210
- https://github.com/godotengine/godot/pull/105801
- https://github.com/godotengine/godot/issues/106484
- https://github.com/godotengine/godot/issues/114854
- https://github.com/godotengine/godot/issues/64353
- https://github.com/godotengine/godot/issues/99935
- https://github.com/godotengine/godot/issues/97473
- https://github.com/godotengine/godot/issues/102968
- https://github.com/godotengine/godot/issues/78754
- https://github.com/godotengine/godot/issues/81435
- https://github.com/godotengine/godot-vscode-plugin/issues/567
- https://github.com/godotengine/godot-proposals/issues/2815
- https://github.com/godotengine/godot/pull/113279
- https://godotengine.org/releases/4.6/
- https://godotengine.org/article/dev-snapshot-godot-4-6-dev-2/
- https://shaggydev.com/2025/09/25/godot-custom-monitoring/
- https://dev.to/ziva/how-to-profile-gdscript-performance-in-godot-4-a-2026-guide-16jn
- https://github.com/godot-extended-libraries/godot-debug-menu
