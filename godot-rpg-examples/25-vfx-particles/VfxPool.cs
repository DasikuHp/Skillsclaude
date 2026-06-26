// VfxPool.cs — Godot 4.6 / .NET 8
// Pool pre-calentado con reciclaje idempotente (signal + Timer de respaldo).
using Godot;
using System.Collections.Generic;

public partial class VfxPool : Node
{
    public static VfxPool Instance { get; private set; }

    private readonly Dictionary<string, Stack<GpuParticles3D>> _pools = new();

    public override void _Ready() => Instance = this;

    private GpuParticles3D Make(PackedScene scene)
    {
        var p = scene.Instantiate<GpuParticles3D>();
        AddChild(p);
        p.OneShot = true;
        p.Emitting = false;
        p.Restart();          // pre-warm: compila el shader al cargar
        p.Emitting = false;
        return p;
    }

    public void Play(string key, PackedScene scene, Vector3 worldPos, Vector3 normal)
    {
        if (!_pools.TryGetValue(key, out var stack))
        {
            stack = new Stack<GpuParticles3D>();
            _pools[key] = stack;
        }
        var p = stack.Count > 0 ? stack.Pop() : Make(scene);
        p.GlobalPosition = worldPos;
        if (!normal.IsEqualApprox(Vector3.Up) && !normal.IsZeroApprox())
            p.LookAt(worldPos + normal, Vector3.Up);
        p.Restart();

        bool returned = false;
        void Ret()
        {
            if (returned) return;
            returned = true;
            p.Emitting = false;
            _pools[key].Push(p);
        }
        // ATASCO #3: respaldar 'Finished' con un Timer.
        p.Finished += Ret;
        float safety = p.Lifetime * 1.5f / Mathf.Max(p.SpeedScale, 0.01f);
        GetTree().CreateTimer(safety).Timeout += Ret;
    }
}
