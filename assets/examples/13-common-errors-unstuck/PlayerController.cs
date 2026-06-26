using Godot;

public partial class PlayerController : Node3D
{
    private Node3D _target;
    private Node3D _emitter;

    public override void _Ready()
    {
        // Nil: GetNodeOrNull + guard. NUNCA GetNode en el constructor.
        var hud = GetNodeOrNull<Control>("%HUD");
        if (hud != null) hud.Visible = true;

        // Refs cruzadas: difiere hasta que todo el arbol exista.
        CallDeferred(nameof(WireCrossRefs));
    }

    private void WireCrossRefs()
    {
        _emitter = GetTree().GetFirstNodeInGroup("boss") as Node3D;
        // Guard idempotente con SignalName.* (validado), no string crudo.
        if (_emitter != null && !_emitter.IsConnected(Node.SignalName.TreeExiting, Callable.From(OnEmitterGone)))
            _emitter.TreeExiting += OnEmitterGone;
    }

    public void Attack()
    {
        // queue_free no anula la ref: valida antes de usar.
        if (GodotObject.IsInstanceValid(_target))
            _target.Call("take_damage", 10);
    }

    private void OnEmitterGone() { }

    // C# NO desconecta solo todas las senales al liberar: hazlo aqui (evita NRE sobre nodo muerto).
    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_emitter) &&
            _emitter.IsConnected(Node.SignalName.TreeExiting, Callable.From(OnEmitterGone)))
            _emitter.TreeExiting -= OnEmitterGone;
    }

    // Fisica SIEMPRE en _PhysicsProcess; muta los cuerpos aqui, no en _Process.
    public override void _PhysicsProcess(double delta) { /* mover CharacterBody3D aqui */ }
}
