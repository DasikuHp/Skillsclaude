using Godot;

// Godot 4.6 / .NET 8 - Autoload "Dialogue". Registrar en Project Settings -> Autoload.
// El delegate de cada senal DEBE terminar en "EventHandler".
// Emision con EmitSignal(SignalName.X, ...). La UI conecta con += (fuertemente tipado).
// Gotcha 4.6: nombres de tracks de AnimationPlayer pasaron de String a StringName;
// si disparas animaciones por nombre, recompila el ensamblado C# y usa StringName.
public partial class DialogueManager : Node
{
    [Signal] public delegate void LineDisplayedEventHandler(DialogueLine line);
    [Signal] public delegate void ChoicesPresentedEventHandler(Godot.Collections.Array<DialogueChoice> choices);
    [Signal] public delegate void DialogueEndedEventHandler();

    private readonly Godot.Collections.Dictionary<StringName, bool> _flags = new();

    public void Start(DialogueLine line) => Advance(line);

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

    public void Choose(DialogueChoice choice) => Advance(choice.NextLine);

    public void SetFlag(StringName key, bool value = true) => _flags[key] = value;
}
