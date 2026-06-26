// ImpactVfx.cs — Godot 4.6 / .NET 8
// NOTA: la clase es GpuParticles3D (PascalCase), Aabb, VisibilityAabb, OneShot.
// No corre en Web (export web solo GDScript): ten un equivalente .gd si exportas a Web.
using Godot;

public partial class ImpactVfx : GpuParticles3D
{
    public override void _Ready()
    {
        OneShot = true;
        Emitting = false;
        // ATASCO #1: AABB amplio para evitar culling del emisor.
        VisibilityAabb = new Aabb(new Vector3(-2, -2, -2), new Vector3(4, 4, 4));
        ExtraCullMargin = 4.0f;
    }

    public void PlayAt(Vector3 worldPos, Vector3 surfaceNormal)
    {
        GlobalPosition = worldPos;
        if (!surfaceNormal.IsEqualApprox(Vector3.Up) && !surfaceNormal.IsZeroApprox())
            LookAt(worldPos + surfaceNormal, Vector3.Up);
        // ATASCO #2: Restart(), NO Emitting = true, para re-disparar one-shots.
        Restart();
    }
}
