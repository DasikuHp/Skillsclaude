using Godot;

// Godot 4.6 / .NET 8 - Linea de dialogo como Resource. [GlobalClass] la expone en
// el menu "New Resource" del editor. Idiomatico: partial class, [Export] sobre propiedades.
[GlobalClass]
public partial class DialogueLine : Resource
{
    [Export] public string Speaker { get; set; } = "";
    [Export(PropertyHint.MultilineText)] public string Text { get; set; } = "";
    [Export] public Godot.Collections.Array<DialogueChoice> Choices { get; set; } = new();
    [Export] public DialogueLine NextLine { get; set; }
}

[GlobalClass]
public partial class DialogueChoice : Resource
{
    [Export] public string Label { get; set; } = "";
    [Export] public DialogueLine NextLine { get; set; }
    [Export] public string Condition { get; set; } = "";
}
