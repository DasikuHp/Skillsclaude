## Adjudicación del debate (Tema #18)

Los tres dossiers (docs / veterano / escéptico) están **fuertemente alineados** en el núcleo: el modo de fallo dominante es el "Godot-3-ismo", y la mejor forma de la skill es tabla MAL→BIEN + errores literales + acciones solo-editor. Apenas hubo contradicciones; el trabajo de juez fue **fusionar lo nicho** y resolver matices.

### Acuerdos unánimes (incluidos sin reservas)
- Tabla de traducción G3→4.6 (export, onready, tool, yield→await, emit_signal→.emit, connect→Callable, instance→instantiate, tipados, `&`/`^`, super, @abstract).
- `emit_signal`/`Object.connect(string,...)` siguen existiendo pero SOLO para nombres dinámicos. Los tres lo dicen igual; lo mantengo como regla explícita.
- C#: `partial` obligatorio, sufijo `EventHandler`, `SignalName/MethodName/PropertyName`, `GetNode<T>`, `GD.Print`, `Godot.Collections`, **sin C# en web**.
- StringName breaking en AnimationPlayer (GH-110767): compatible en GDScript, ROMPE C#. Los tres recalcan "NO afecta nombres de track" — lo conservo literal porque es una confusión típica.
- `.tscn`/`uid://`/`load_steps`: no editar a mano, usar Project > Tools > Upgrade Project Files, no inventar UIDs.
- CLI `--check-only`/`--headless`/`--import` como sustituto del Play.
- Shaders `SCREEN_TEXTURE`/`DEPTH_TEXTURE` removidos → hints.

### Discrepancias y cómo las adjudiqué
1. **Códigos de error C# (analyzers).** El veterano da IDs concretos (`GD0001`, `GD0202`, `GD0102`, `GD0301`); docs y escéptico solo describen el síntoma textual. Adjudiqué: incluir `GD0001`/`GD0202` (los más útiles y verificables: el `GD0001` "Missing partial modifier" es el oficial documentado), y mantener el síntoma textual `does not contain a definition for 'SignalName'` como entrada de búsqueda paralela. Omití `GD0102`/`GD0301` del cuerpo por no sobrecargar, mencionando solo el comportamiento.
2. **Mensaje literal exacto de `@onready` en `_init`.** El veterano lo da como `Invalid call. Nonexistent function 'x' in base 'null instance'`. Es plausible pero el texto exacto depende del uso; lo mantuve como runtime y marcado "(runtime)" para no afirmar un literal frágil como si fuera canónico.
3. **Jolt default.** El escéptico aporta el matiz crítico que los otros dos no enfatizan: Jolt es default **solo en proyectos nuevos**, no en migrados (hay que tocar `physics/3d/physics_engine`). Prioricé esta versión porque coincide con los FACTS del prompt ("new projects") y desatasca un consejo falso común. Lo puse en la tabla addon-vs-construir.
4. **Cache de build C# (`CS0246`).** Solo el escéptico (GH-68411). Es anti-stuck puro y verificable; lo incluí porque un agente que ve `CS0246` asumirá error de código cuando suele ser cache.
5. **Bugs nicho de tipados (Variant no supertipo GH-105843, ternario GH-110628, Dictionary[Script] GH-103569, anidamiento GH-12224).** Repartidos entre docs/veterano/escéptico. Incluí los dos de mayor impacto práctico (anidamiento no soportado + Variant no supertipo) en la tabla de errores; los otros quedan citados en Fuentes para no inflar.
6. **`emit` no awaitable (GH-86862).** Solo el escéptico. Es un error de lógica frecuente en LLMs; lo subí a "Cómo no quedarte atascado".

### Descartado por dudoso/no verificable
- URL `godot-mcp.abyo.net` y `straydragon.github.io` (terceros no oficiales): no las cito como fuente primaria, prefiero docs oficiales y issues de GitHub.
- No afirmé versión exacta de mantenimiento más allá de "~4.6.3" según FACTS del prompt (los dossiers decían 4.6.1; respeto el FACT más reciente del juez).
- "GodotCon Boston mayo 2025 Web .NET prototipo": lo dejé fuera del cuerpo (futurible) y solo como contexto de por qué C# no va en web hoy.

### Sesgo ponytail aplicado
Reforcé "valida con `--check-only` antes de afirmar" y "deja que el editor reescriba `.tscn`" como el verdadero "código que no escribes". El veredicto ata el índice-por-error con la filosofía de reuso nativo.

## Fuentes
- https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- https://github.com/godotengine/godot-docs/blob/master/tutorials/migrating/upgrading_to_godot_4.6.rst
- https://godotengine.org/releases/4.6/
- https://godotengine.org/article/maintenance-release-godot-4-6-1/
- https://docs.godotengine.org/en/latest/tutorials/scripting/gdscript/gdscript_basics.html
- https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html
- https://github.com/godotengine/godot/pull/70967
- https://github.com/godotengine/godot/issues/109574
- https://github.com/godotengine/godot/issues/82268
- https://github.com/godotengine/godot/issues/115624
- https://github.com/godotengine/godot/issues/105843
- https://github.com/godotengine/godot/issues/110628
- https://github.com/godotengine/godot/issues/103569
- https://github.com/godotengine/godot-proposals/issues/12224
- https://github.com/godotengine/godot/issues/86862
- https://github.com/godotengine/godot/issues/68411
- https://github.com/godotengine/godot/issues/97728
- https://docs.godotengine.org/en/4.6/tutorials/physics/using_jolt_physics.html
- https://github.com/godot-jolt/godot-jolt
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_signals.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_exports.html
- https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- https://www.gdquest.com/library/godot_4_6_workflow_changes/
- https://godotengine.org/article/uid-changes-coming-to-godot-4-4/
- https://github.com/nathanhoad/godot_dialogue_manager
