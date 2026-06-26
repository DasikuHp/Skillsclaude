using Godot;

// 'partial' es OBLIGATORIO en toda clase que derive de GodotObject:
// los source generators del Godot.NET.Sdk generan la otra mitad
// (SignalName, MethodName, PropertyName, registro de [Export] y helpers EmitSignalXxx).
// Sin 'partial' -> GD0001.
public partial class Player : CharacterBody3D
{
    // [Export] sobre PROPIEDAD con setter (read-only -> GD0103). Aparece en el inspector.
    [Export] public float Speed { get; set; } = 6.0f;

    // El delegate de señal DEBE terminar en 'EventHandler' (si no -> GD0201)
    // y retornar void (si no -> GD0203). Parametros Variant-compatibles (si no -> GD0202).
    [Signal] public delegate void HealthChangedEventHandler(int oldHp, int newHp);

    private int _hp = 100;
    private Node3D _target;
    private readonly System.Threading.CancellationTokenSource _cts = new();

    public override void _Ready()
    {
        // Cachea nodos en _Ready, NO en _Process (cada GetNode cruza la frontera C#<->engine).
        _target = GetNodeOrNull<Node3D>("%Target");
    }

    // OJO: delta es 'double' en C# (no float). Castea al multiplicar por floats.
    public override void _PhysicsProcess(double delta)
    {
        float dir = Input.GetAxis("left", "right");
        Velocity = Velocity with { X = dir * Speed };
        MoveAndSlide();
    }

    public void Damage(int amount)
    {
        int old = _hp;
        _hp -= amount;
        // Helper tipado generado (preferido). Equivale a EmitSignal(SignalName.HealthChanged, old, _hp).
        EmitSignalHealthChanged(old, _hp);
    }

    public override void _ExitTree() => _cts.Cancel(); // cancela awaits pendientes al salir del arbol

    public async void FadeAndReset()
    {
        // ToSignal devuelve un SignalAwaiter (no un Task). SceneTreeTimer.SignalName.Timeout.
        await ToSignal(GetTree().CreateTimer(1.5f), SceneTreeTimer.SignalName.Timeout);

        // Tras el await el nodo pudo morir (cambio de escena, QueueFree). Revalida SIEMPRE.
        if (_cts.IsCancellationRequested || !IsInstanceValid(this)) return;
        Position = Vector3.Zero;
    }

    public void MoveTarget(Vector3 pos)
    {
        // IsInstanceValid es la unica forma correcta de saber si el objeto nativo vive.
        // NUNCA compares con null: la ref managed puede ser no-null sobre un nativo liberado.
        if (GodotObject.IsInstanceValid(_target) && !_target.IsQueuedForDeletion())
            _target.GlobalPosition = pos;
    }
}
