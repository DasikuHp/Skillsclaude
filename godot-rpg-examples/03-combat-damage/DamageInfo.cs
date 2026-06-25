// DamageInfo.cs
// Equivalente C# (.NET 8) del Resource de golpe. [GlobalClass] para verlo en el inspector.
// Godot 4.6. Usa StringName para tipos de dano (coherente con las pistas StringName de 4.6).
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class DamageInfo : Resource
{
    [Export] public float Amount { get; set; } = 10.0f;
    [Export] public StringName Type { get; set; } = "physical";
    [Export] public float Knockback { get; set; } = 6.0f;
    [Export] public Dictionary<StringName, float> Resistances { get; set; } = new();

    // Runtime: quien golpea. No exportado.
    public Node3D Source { get; set; }
}
