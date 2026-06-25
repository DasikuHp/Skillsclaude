using Godot;

// EnemyAvoidance.cs
// Enemigo con avoidance RVO (Godot 4.6, .NET 8). Usar solo si hay muchos
// enemigos apretados. La velocidad real se aplica en el callback VelocityComputed.
public partial class EnemyAvoidance : CharacterBody3D
{
    [Export] public float Speed { get; set; } = 4.0f;
    [Export] public float Gravity { get; set; } = 9.8f;
    [Export] public Node3D Target { get; set; }

    private NavigationAgent3D _agent;

    public override void _Ready()
    {
        _agent = GetNode<NavigationAgent3D>("NavigationAgent3D");
        // SIN avoidance_enabled = true, la senal VelocityComputed NO se emite.
        _agent.AvoidanceEnabled = true;
        _agent.VelocityComputed += OnSafeVelocity;
        CallDeferred(MethodName.Setup);
    }

    private async void Setup()
    {
        await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
        if (Target != null)
            _agent.TargetPosition = Target.GlobalPosition;
    }

    public override void _PhysicsProcess(double delta)
    {
        // Gravedad aparte: el avoidance 2D (UseAvoidance3D == false, por defecto)
        // ignora el eje Y, asi que NO la metemos por SetVelocity().
        if (!IsOnFloor())
        {
            Vector3 v = Velocity;
            v.Y -= Gravity * (float)delta;
            Velocity = v;
        }

        if (_agent.IsNavigationFinished())
        {
            MoveAndSlide();
            return;
        }

        if (Target != null)
            _agent.TargetPosition = Target.GlobalPosition;

        Vector3 next = _agent.GetNextPathPosition();
        Vector3 desired = GlobalPosition.DirectionTo(next) * Speed;
        _agent.SetVelocity(desired);                     // NO mover aqui; esperar senal
    }

    private void OnSafeVelocity(Vector3 safeVelocity)
    {
        // El avoidance 2D (use_3d_avoidance == false, por defecto) calcula solo en
        // el plano x/z, asi que safe_velocity.Y siempre llega en 0. Si hicieramos
        // Velocity = safeVelocity destruiriamos la gravedad cada frame. Reaplicamos
        // la Y propia (issue #108252 ademas la pone en 0 al terminar la nav).
        Vector3 v = safeVelocity;
        v.Y = Velocity.Y;
        Velocity = v;
        MoveAndSlide();
    }
}
