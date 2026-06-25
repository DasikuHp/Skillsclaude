using Godot;

// Alternativa C# (.NET 8) cuando el flash va sobre un ShaderMaterial dedicado
// y NO compartes el recurso entre enemigos (web no soporta C#: usa GDScript ahi).
public partial class FlashSharedMaterial : MeshInstance3D
{
    public void Hit()
    {
        var mat = (ShaderMaterial)GetActiveMaterial(0);
        // Por codigo directo: SetShaderParameter("flash", v) SIN barra.
        mat.SetShaderParameter("flash", 1.0f);

        // Por Tween/AnimationPlayer: property path "shader_parameter/<name>" CON barra.
        Tween t = CreateTween();
        t.TweenProperty(mat, "shader_parameter/flash", 0.0f, 0.15).From(1.0f);
    }
}
