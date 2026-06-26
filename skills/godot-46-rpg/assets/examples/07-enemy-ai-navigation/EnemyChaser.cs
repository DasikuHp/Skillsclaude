using Godot;

// EnemyChaser.cs
// Enemigo que persigue al jugador usando NavigationAgent3D nativo (Godot 4.6, .NET 8).
// Escena: CharacterBody3D > [NavigationAgent3D, RepathTimer (Timer), CollisionShape3D]
public partial class EnemyChaser : CharacterBody3D
{
    [Export] public float Speed { get; set; } = 4.0f;
    [Export] public float Gravity { get; set; } = 9.8f;
    [Export] public Node3D Target { get; set; }

    private NavigationAgent3D _agent;
    private Timer _repathTimer;

    public override void _Ready()
    {
        _agent = GetNode<NavigationAgent3D>("NavigationAgent3D");
        _repathTimer = GetNode<Timer>("RepathTimer");
        _repathTimer.Timeout += OnRepath;
        CallDeferred(MethodName.Setup);
    }

    private async void Setup()
    {
        // Issue #82209: el path sale vacio en C# si se pide antes de la primera
        // sincronizacion del NavigationServer. Esperar un frame fisico.
        await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
        RefreshTarget();
    }

    private void OnRepath() => RefreshTarget();

    private void RefreshTarget()
    {
        // Fijar siempre el target. IsTargetReachable() evalua contra el path YA
        // computado (el target anterior), asi que usarla como guarda aqui crea un
        // deadlock huevo-gallina: en la primera llamada devuelve false y el enemigo
        // nunca arranca. Si quieres fallback, consultala en un frame posterior.
        if (Target != null)
            _agent.TargetPosition = Target.GlobalPosition;
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector3 velocity = Velocity;

        if (!IsOnFloor())
            velocity.Y -= Gravity * (float)delta;

        if (_agent.IsNavigationFinished())
        {
            velocity.X = 0f;
            velocity.Z = 0f;
            Velocity = velocity;
            MoveAndSlide();
            return;
        }

        // Obligatorio cada frame fisico tras setear target.
        Vector3 next = _agent.GetNextPathPosition();
        Vector3 dir = GlobalPosition.DirectionTo(next);
        velocity.X = dir.X * Speed;
        velocity.Z = dir.Z * Speed;
        Velocity = velocity;
        MoveAndSlide();
    }
}
