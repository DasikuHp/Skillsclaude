## Notas de investigación — Dominio #6: Diálogo y quests (Godot 4.6)

### Verificaciones hechas (WebSearch, junio 2026)
- **C# signals 4.6**: confirmado contra doc oficial. Declaración `[Signal] public delegate void XEventHandler(args)` (el nombre DEBE terminar en `EventHandler`). Emisión `EmitSignal(SignalName.X, args)`. Conexión idiomática con `+=` (`MySignal += handler`). No se puede usar `Invoke` en eventos ligados a señales Godot. Fuente: docs.godotengine.org C# signals.
- **Patrón Resource + señales + autoload**: confirmado por múltiples fuentes independientes (StraySpark, Coding Quests, Wayline, gameidea). El manager emite `line_displayed` / `choices_presented` / `dialogue_ended` y la UI escucha — consenso claro.
- **Recursión de Resource para ramas**: confirmada como patrón en foro oficial; advertencia sobre ciclos/serialización → usar next_id + diccionario para grafos cíclicos.
- **Dialogue Manager 4 = 4.6+**, Dialogic 2 = 4.4+ (corre en 4.6). Verificado en resultados de búsqueda.

### Hechos 4.6 aplicados
- Typed dictionaries `Dictionary[StringName, bool]` para flags.
- String → StringName en tracks de AnimationPlayer (breaking 4.5→4.6) → recompilar C#. Relevante si el diálogo dispara animaciones por nombre.
- `Expression` para condiciones data-driven (clase estable, no inventada).
- `[GlobalClass]` para exponer Resources en el menú New Resource.

### Decisiones de diseño
- Manager NO conoce la UI (solo emite señales). Regla repetida en todas las fuentes.
- Eventos, no polling, para objetivos de quest (`enemy.died.connect`).
- Estado nunca en nodos de escena.
- Híbrido addon-backend + UI propia como mejor compromiso.

### Pendiente / cautela
- La conexión de señales C# con args vía Callable.Bind sigue siendo trampa (issue #71895); recomendación práctica `+=` o `EmitSignal(SignalName.X)`, validada contra doc oficial.

## Fuentes
- https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources
- https://docs.godotengine.org/en/4.6/getting_started/step_by_step/signals.html
- https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/c_sharp_signals.html
- https://github.com/nathanhoad/godot_dialogue_manager
- https://github.com/nathanhoad/godot_dialogue_manager/blob/main/docs/Conditions_Mutations.md
- https://github.com/dialogic-godot/dialogic
- https://docs.dialogic.pro/
- https://github.com/Chevifier/QuestManager/blob/main/documentation/Quest_Manager_API.md
- https://github.com/shomykohai/quest-system
- https://github.com/shomykohai/advanced-quest-system-example/
- https://itssho.my/blog/article/how-i-handle-quests-in-godot
- https://github.com/Rubonnek/quest-manager
- https://github.com/TheWalruzz/godot-questify
- https://forum.godotengine.org/t/resource-recursion-for-branching-and-repeating-dialog-system/52517
- https://github.com/godotengine/godot/issues/71895
- https://dev.to/christinec_dev/lets-learn-godot-4-by-making-an-rpg-part-17-basic-npc-quest-2f8b
- https://codingquests.io/blog/godot-4-dialogue-system-tutorial
- https://gameidea.org/2026/02/03/making-dialogue-system-in-godot/
- https://www.wayline.io/blog/godot-dialogue-system-signals-resources
