using Godot;

public partial class Spawner : Node3D
{
    // Ruta conocida: GD.Load directo. Cargas la PackedScene importada, no el .glb crudo.
    private readonly PackedScene _enemyScene =
        GD.Load<PackedScene>("res://assets/enemies/goblin.glb");

    public Node3D SpawnStatic()
    {
        var enemy = _enemyScene.Instantiate<Node3D>();
        AddChild(enemy);
        return enemy;
    }

    public Node3D? Spawn(string path)
    {
        var packed = ResourceLoader.Load<PackedScene>(path);
        if (packed == null)
        {
            GD.PushError($"No se pudo cargar PackedScene: {path}");
            return null;
        }
        var inst = packed.Instantiate<Node3D>();
        AddChild(inst);
        return inst;
    }

    // 4.6: current_animation/autoplay/etc. son StringName (GH-110767).
    // En C# eso cambia firmas: usa StringName, no string.
    public void PlayRun(AnimationPlayer anim)
    {
        StringName clip = "locomotion/Run";
        if (anim.CurrentAnimation != clip)
            anim.Play(clip);
    }
}
