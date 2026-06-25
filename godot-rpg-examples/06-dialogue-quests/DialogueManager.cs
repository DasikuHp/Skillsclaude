using Godot;

// Godot 4.6 / .NET 8 - Autoload "Dialogue". Registrar en Project Settings -> Autoload.
// El delegate de cada senal DEBE terminar en "EventHandler".
// Emision con EmitSignal(SignalName.X, ...). La UI conecta con += (fuertemente tipado).
// Gotcha 4.6 (GH-110767): propiedades de nombre de animacion de AnimationPlayer
// (current_animation, assigned_animation, autoplay, get_queue()) pasaron a StringName;
// leerlas como string rompe al migrar de 4.5 (un literal sigue compilando por conversion implicita).
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
