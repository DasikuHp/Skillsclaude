// HitBox3D.cs
// Hitbox de melee en C# (.NET 8) para Godot 4.6.
// Patron: habilita/deshabilita esta Area3D desde la animacion de ataque
// (Call Method Track llamando StartAttack()/EndAttack()).
// Gotcha 4.6 (GH-110767): propiedades de nombre de animacion de AnimationPlayer
// (current_animation, assigned_animation, autoplay, get_queue(), senal current_animation_changed)
// pasaron de String a StringName; leerlas como string rompe en compilacion al migrar de 4.5.
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
        // Owner solo apunta a la victima si la hurtbox vive dentro de una escena
        // instanciada cuyo root lleva take_damage; si se anadio en runtime sin owner,
        // Owner es null. Fallback robusto al padre directo.
        Node victim = area.Owner ?? area.GetParent();
        if (victim == null) return;
        ulong id = victim.GetInstanceId();
        if (_alreadyHit.ContainsKey(id)) return; // anti doble golpe por swing
        _alreadyHit[id] = true;
        if (victim.HasMethod("take_damage"))
        {
            // source es un campo transitorio por golpe: duplicamos para no mutar el
            // .tres compartido entre atacantes (aliasing). Ver Resource.Duplicate().
            var info = (DamageInfo)DamageInfo.Duplicate();
            info.Source = Owner as Node3D;
            victim.Call("take_damage", info);
        }
    }
}
