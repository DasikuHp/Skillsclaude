// HitBox3D.cs
// Hitbox de melee en C# (.NET 8) para Godot 4.6.
// GOTCHA 4.6: los nombres de pista de AnimationPlayer pasaron de String a StringName.
// Si disparas StartAttack()/EndAttack() via Call Method Track, RECOMPILA el proyecto C#
// o esas llamadas pueden romperse silenciosamente.
// GOTCHA: AreaEntered solo se emite si Monitoring == true.
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class HitBox3D : Area3D
{
    [Export] public DamageInfo DamageInfo { get; set; }

    private readonly Dictionary<ulong, bool> _alreadyHit = new();
    private CollisionShape3D _shape;

    public override void _Ready()
    {
        _shape = GetNode<CollisionShape3D>("HitShape");
        Monitoring = true; // sin esto, AreaEntered nunca dispara
        AreaEntered += OnAreaEntered;
    }

    public void StartAttack()
    {
        _alreadyHit.Clear();   // limpiar ANTES de habilitar
        _shape.Disabled = false; // habilita el SHAPE, no el Area3D
    }

    public void EndAttack() => _shape.Disabled = true;

    private void OnAreaEntered(Area3D area)
    {
        Node victim = area.Owner;
        if (victim == null) return;
        ulong id = victim.GetInstanceId();
        if (_alreadyHit.ContainsKey(id)) return; // anti doble golpe por swing
        _alreadyHit[id] = true;
        if (victim.HasMethod("take_damage"))
        {
            DamageInfo.Source = Owner as Node3D;
            victim.Call("take_damage", DamageInfo);
        }
    }
}
