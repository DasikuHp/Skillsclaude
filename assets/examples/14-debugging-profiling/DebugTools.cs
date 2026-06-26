using Godot;
using System.Diagnostics;

// Autoload "DebugTools". Web NO soporta C# (renderer Compatibility): si exportas
// a web, usa la version GDScript. assert de GDScript no existe en C#; usa
// System.Diagnostics.Debug.Assert (tambien se elimina en build Release).
public partial class DebugTools : Node
{
    public override void _Ready()
    {
        RegisterMonitor("game/enemies_alive", Callable.From(CountEnemies));
        RegisterMonitor("game/projectile_pool", Callable.From(PoolSize));
    }

    private static void RegisterMonitor(string id, Callable fn)
    {
        // Evita "Custom monitor 'X' already exists."
        if (!Performance.HasCustomMonitor(id))
            Performance.AddCustomMonitor(id, fn);
    }

    public override void _ExitTree()
    {
        foreach (string id in new[] { "game/enemies_alive", "game/projectile_pool" })
            if (Performance.HasCustomMonitor(id))
                Performance.RemoveCustomMonitor(id);
    }

    // El callable debe devolver un numero >= 0.
    private int CountEnemies() => GetTree().GetNodesInGroup("enemies").Count;
    private int PoolSize() => Mathf.Max(0, GetTree().GetNodesInGroup("projectiles").Count);

    public void ApplyDamage(int amount)
    {
        Debug.Assert(amount >= 0, $"dano negativo: {amount}"); // eliminado en Release
        GD.PrintStack();                                       // equivalente de print_stack
        GD.Print(new StackTrace(true).ToString());             // stack .NET completo
        GD.Print($"dano aplicado: {amount}");
    }

    public void CheckLeaks()
    {
        Node.PrintOrphanNodes();
        GD.Print("Orphans: ", Performance.GetMonitor(Performance.Monitor.ObjectOrphanNodeCount));
    }

    // No mezclar con el menu del editor (godot#64353); setear antes del 1er frame.
    public void SetDebugVisuals(bool enabled)
    {
        GetTree().DebugCollisionsHint = enabled;
        GetTree().DebugNavigationHint = enabled;
    }
}
