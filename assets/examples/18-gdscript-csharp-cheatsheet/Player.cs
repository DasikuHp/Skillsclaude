// ==========================================================
// INCORRECTO (lo que un LLM tiende a generar)
// ==========================================================
//
// public class Player : KinematicBody          // clase 3.x, sin partial -> GD0001
// {
//     [Signal] public delegate void Died();    // sin sufijo EventHandler -> GD0201
//     public override void _Ready() {
//         Console.WriteLine("hi");              // no aparece en Output del editor
//         EmitSignal("Died");                   // string magico
//         var n = GetNode("Camera") as Camera3D;// cast manual
//     }
// }

// ==========================================================
// CORRECTO Godot 4.6 / .NET 8
// ==========================================================
using Godot;

public partial class Player : CharacterBody3D   // partial OBLIGATORIO (source generators)
{
    [Signal] public delegate void DiedEventHandler(int score);  // sufijo EventHandler obligatorio

    [Export] public int Hp { get; set; } = 100;

    public override void _Ready()
    {
        Camera3D cam = GetNode<Camera3D>("Camera3D");  // generico tipado
        Died += OnDied;                                 // event C# nativo
        EmitSignal(SignalName.Died, 42);                // StringName generado, no string
        GD.Print("ready");                              // GD.Print, no Console.WriteLine

        // StringName breaking 4.6 (GH-110767): CurrentAnimation es StringName en C#
        var anim = GetNode<AnimationPlayer>("AnimationPlayer");
        anim.CurrentAnimation = (StringName)"run";       // cast explicito, no string crudo
    }

    private void OnDied(int score) => GD.Print("murio con ", score);
}
