## 6. Diálogo y quests

Diálogo y quests son, en el fondo, **datos + estado + eventos**. La tentación es construir un grafo de nodos custom con su propio editor; el camino sólido en Godot 4.6 es no construir casi nada: `Resource` para los datos serializables, `signal` para desacoplar lógica de UI, y un **autoload (singleton)** que custodia el estado runtime y el save/load. Tres conceptos nativos cubren el 90% de un RPG ([StraySpark](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources), [Coding Quests](https://codingquests.io/blog/godot-4-dialogue-system-tutorial)).

### Enfoque nativo recomendado

- **Datos como `Resource`** (`class_name DialogueLine extends Resource`, `class_name Quest extends Resource`). Se editan en el Inspector, se guardan como `.tres`/`.res` y versionan en git. Un grafo de diálogo ramificado es simplemente un `Resource` que referencia a otros vía `@export` (recursión de `Resource`) — patrón confirmado en el [foro oficial](https://forum.godotengine.org/t/resource-recursion-for-branching-and-repeating-dialog-system/52517).
- **Señales para desacoplar**: el manager emite `line_displayed`, `choices_presented`, `dialogue_ended`; la UI escucha. El manager **nunca** conoce la UI. Doc oficial 4.6: [Using signals](https://docs.godotengine.org/en/4.6/getting_started/step_by_step/signals.html).
- **Autoload (singleton)**: registrado en *Project Settings → Autoload*. `DialogueManager`/`QuestManager` mantienen el estado en memoria y escuchan eventos de gameplay. **Regla de oro**: jamás guardes estado de quest en nodos de escena — se pierde al recargar; vive en el `Resource` o en el autoload ([StraySpark](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources)).
- **Eventos, no polling**: conecta `enemy.died.connect(QuestManager.on_enemy_killed)` en lugar de revisar progreso en `_process`. Menos overhead y menos acoplamiento.
- **`Dictionary[K, V]` tipado (4.6)** para flags de conversación/mundo (`var flags: Dictionary[StringName, bool]`), y **`Expression`** para condiciones dinámicas sin hardcodear `if`.

### GDScript

```gdscript
# dialogue_line.gd — dato puro, sin nodos
class_name DialogueLine extends Resource

@export var speaker: String
@export_multiline var text: String
@export var choices: Array[DialogueChoice] = []   # vacío = avance lineal
@export var next_line: DialogueLine                # null = fin de la rama
```

```gdscript
# dialogue_choice.gd
class_name DialogueChoice extends Resource

@export var label: String
@export var next_line: DialogueLine
@export var condition: String = ""   # ej. "flags.has(&\"talked_to_elder\")"
```

```gdscript
# dialogue_manager.gd — autoload "Dialogue". NO conoce la UI.
extends Node

signal line_displayed(line: DialogueLine)
signal choices_presented(choices: Array[DialogueChoice])
signal dialogue_ended

var flags: Dictionary[StringName, bool] = {}

func start(line: DialogueLine) -> void:
    _advance(line)

func _advance(line: DialogueLine) -> void:
    if line == null:
        dialogue_ended.emit()
        return
    line_displayed.emit(line)
    var available := _filter(line.choices)
    if not available.is_empty():
        choices_presented.emit(available)

func choose(choice: DialogueChoice) -> void:
    _advance(choice.next_line)

func continue_line(line: DialogueLine) -> void:
    _advance(line.next_line)

func set_flag(key: StringName, value: bool = true) -> void:
    flags[key] = value

func _filter(choices: Array[DialogueChoice]) -> Array[DialogueChoice]:
    var out: Array[DialogueChoice] = []
    for c in choices:
        if c.condition.is_empty() or _eval(c.condition):
            out.append(c)
    return out

func _eval(condition: String) -> bool:
    var expr := Expression.new()
    if expr.parse(condition, ["flags"]) != OK:
        push_warning("Condición inválida: %s" % condition)
        return false
    var result: Variant = expr.execute([flags], self)
    if expr.has_execute_failed():
        push_warning("Fallo al evaluar: %s" % condition)
        return false
    return bool(result)
```

Quests con el mismo patrón, actualizadas por señal:

Cada `class_name` global vive en **su propio archivo** (GDScript permite un solo `class_name` por script):

```gdscript
# quest_objective.gd
class_name QuestObjective extends Resource
enum Kind { KILL, COLLECT, TALK, REACH }
@export var kind: Kind = Kind.KILL
@export var target: StringName
@export var required: int = 1
@export var progress: int = 0
func is_done() -> bool: return progress >= required
```

```gdscript
# quest.gd
class_name Quest extends Resource
@export var id: StringName
@export var title: String
@export var objectives: Array[QuestObjective] = []
func is_complete() -> bool:
    return objectives.all(func(o: QuestObjective) -> bool: return o.is_done())
```

```gdscript
# quest_manager.gd — autoload "Quests". Sin polling.
extends Node

signal objective_updated(quest: Quest, objective: QuestObjective)
signal quest_completed(quest: Quest)

var active: Array[Quest] = []

func on_enemy_killed(enemy_id: StringName) -> void:
    for q in active:
        for obj in q.objectives:
            if obj.kind == QuestObjective.Kind.KILL and obj.target == enemy_id and not obj.is_done():
                obj.progress += 1
                objective_updated.emit(q, obj)
                if q.is_complete():
                    quest_completed.emit(q)
```

### C# (.NET 8)

Mismo modelo, con idioma C# idiomático: `partial class : Resource/Node`, `[Export]`, `[Signal] delegate ...EventHandler`, `EmitSignal(SignalName.X, ...)`. La conexión a manejadores tipados se hace con el operador `+=` (confirmado por la [doc oficial de C# signals](https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/c_sharp_signals.html)).

```csharp
using Godot;

[GlobalClass]
public partial class DialogueLine : Resource
{
    [Export] public string Speaker { get; set; } = "";
    [Export(PropertyHint.MultilineText)] public string Text { get; set; } = "";
    [Export] public Godot.Collections.Array<DialogueChoice> Choices { get; set; } = new();
    [Export] public DialogueLine NextLine { get; set; }
}
```

```csharp
using Godot;

// Autoload "Dialogue". El delegate DEBE terminar en "EventHandler".
public partial class DialogueManager : Node
{
    [Signal] public delegate void LineDisplayedEventHandler(DialogueLine line);
    [Signal] public delegate void ChoicesPresentedEventHandler(Godot.Collections.Array<DialogueChoice> choices);
    [Signal] public delegate void DialogueEndedEventHandler();

    public void Advance(DialogueLine line)
    {
        if (line == null)
        {
            EmitSignal(SignalName.DialogueEnded);
            return;
        }
        EmitSignal(SignalName.LineDisplayed, line);
        if (line.Choices.Count > 0)
            EmitSignal(SignalName.ChoicesPresented, line.Choices);
    }
}
```

```csharp
// En la UI: conexión fuertemente tipada con +=, sin strings ni Callable manual.
public override void _Ready()
{
    var dlg = GetNode<DialogueManager>("/root/Dialogue");
    dlg.LineDisplayed += OnLineDisplayed;        // tipado, refactor-safe
    dlg.DialogueEnded += () => QueueFree();
}
private void OnLineDisplayed(DialogueLine line) { /* pintar UI */ }
```

`[GlobalClass]` va en las clases de datos `Resource` (`DialogueLine`, `DialogueChoice`, `Quest`...) para que aparezcan bajo *New Resource* en el editor; los `Node` manager de autoload **no** lo necesitan, porque se registran en *Project Settings → Autoload* y se instancian por ahí, no se crean desde el menú de Resources.

**Gotcha 4.6 (String → StringName)**: en 4.6 varias propiedades de *nombre de animación* de `AnimationPlayer` (`current_animation`, `assigned_animation`, `autoplay`, `get_queue()`, señal `current_animation_changed`) pasaron de `String` a `StringName` (GH-110767). Si tus diálogos disparan animaciones por nombre (`player.Play("talk")`), **recompila el ensamblado C#** tras subir de 4.5; pasa los nombres como `StringName` (`new StringName("talk")` o el literal `&"talk"` en GDScript) para evitar conversiones implícitas costosas. Para conectar señales a métodos GDScript snake_case desde C#, sigue usando `Connect("line_displayed", Callable.From(...))`; para señales entre código C#, prefiere siempre `+=` o `EmitSignal(SignalName.X, ...)` y evita `Callable.Bind`/lambdas con args, históricamente conflictivos ([issue #71895](https://github.com/godotengine/godot/issues/71895)).

### Nodos/clases 4.6

- **`Resource`** — base de todo dato de diálogo/quest. `@export`/`[Export]`, `[GlobalClass]` para que aparezca en *New Resource*.
- **`Node`** (autoload) — host de `DialogueManager`/`QuestManager` y sus señales.
- **`signal` / `Object.connect(Callable)` / `emit`** — bus de eventos nativo. Doc: [Using signals 4.6](https://docs.godotengine.org/en/4.6/getting_started/step_by_step/signals.html).
- **`Expression`** — evalúa condiciones de elección/quest definidas como string en datos.
- **`Dictionary[StringName, bool]`** — typed dictionaries 4.6 para flags de estado.
- **`Callable.From(...)`** (C#) — conexión a manejadores cuando `+=` no aplica (interop con GDScript).

### Pitfalls

- **Estado en nodos de escena**: se pierde al recargar. Mantén progreso de quest y flags de diálogo en el `Resource` o en el autoload ([StraySpark](https://www.strayspark.studio/blog/godot-4-dialogue-quest-systems-signals-resources)).
- **Polling de objetivos en `_process`**: usa señales de gameplay (`enemy.died.connect(...)`); más barato y desacoplado.
- **Referencias circulares entre `Resource`** en grafos con ciclos/repetición: la serialización puede complicarse. Si necesitas ciclos, usa `next_id: StringName` + un `Dictionary[StringName, DialogueLine]` en vez de `@export` directo; reserva la recursión de `@export` para árboles acíclicos ([foro oficial](https://forum.godotengine.org/t/resource-recursion-for-branching-and-repeating-dialog-system/52517)).
- **Mezclar dos modelos de datos**: si adoptas Dialogic (Timelines) y además mantienes tu grafo de `Resource`, duplicas estado. Elige uno como fuente de verdad.
- **C# tras 4.5→4.6**: recompila por `StringName` en tracks de `AnimationPlayer`; no asumas que `string` se autoconvierte sin coste.
- **Versión de addon**: Dialogic 2 requiere ≥4.4 (corre en 4.6); Dialogue Manager 4 apunta a 4.6+. Fija la versión antes de depender de ella (parche actual ~4.6.3).

### Addon vs construirlo

El patrón `Resource` + señales + autoload son ~150 líneas bajo tu control total: ideal si quieres integración estrecha con tu propio save/load y condiciones específicas del RPG. Si el contenido lo escriben no-programadores o quieres ramificación rica sin construir un editor, reutiliza un addon:

| Addon | Para qué | Versión |
|---|---|---|
| [Dialogue Manager (nathanhoad)](https://github.com/nathanhoad/godot_dialogue_manager) | Diálogo "stateless" estilo guion con `if/elif/while`, `set`/`do`, condiciones inline | 4.6+ |
| [Dialogic 2](https://github.com/dialogic-godot/dialogic) | VNs/NPCs con retratos, editor visual de timelines | 4.4+ |
| [shomykohai/quest-system](https://github.com/shomykohai/quest-system) | Quests basadas en Resource, API testeada y extensible (`QuestSystemManagerAPI`), localización CSV/POT | 4.4+ |
| [Chevifier/QuestManager](https://github.com/Chevifier/QuestManager) | Quests, docs claras, arranque rápido | 4.2+ |
| [Questify (TheWalruzz)](https://github.com/TheWalruzz/godot-questify) | Editor visual de quests por grafos | 4.4+ |

**Enfoque híbrido** que recomienda la comunidad: usa el *backend* (parsing/runtime) de un addon y conecta **tu propia UI** a sus señales — evita acoplar tu HUD al estilo del addon.

**Veredicto ponytail:** no construyas un editor de grafos ni un formato de datos propio. Reutiliza `Resource` (datos) + `signal` + un autoload `Node` (estado y save/load), con `Expression` para condiciones y `Dictionary[StringName, bool]` para flags. Para quests serias, monta sobre [shomykohai/quest-system](https://github.com/shomykohai/quest-system); para diálogo ramificado rico, [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) con tu UI conectada a sus señales. Lo único que vale la pena escribir tú es el pegamento (~150 líneas) y la UI.



> **Escalera ponytail:** rung 5 (addon Dialogic) o rung 4 · **net propio:** grafo de Resource o el addon; si construyes, un manager autoload.
