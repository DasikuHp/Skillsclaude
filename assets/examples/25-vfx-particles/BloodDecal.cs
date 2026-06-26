// BloodDecal.cs — Godot 4.6 / .NET 8
// Decal de sangre orientado (-Y local hacia la superficie) con fade por Tween.
using Godot;

public partial class BloodDecal : Decal
{
    [Export] public float Lifetime = 20.0f;
    [Export] public float FadeSeconds = 5.0f;
    [Export] public Texture2D BloodTexture;

    public void Splat(Vector3 hitPos, Vector3 surfaceNormal)
    {
        if (BloodTexture != null)
            TextureAlbedo = BloodTexture; // sin albedo/emission el decal es invisible
        GlobalPosition = hitPos + surfaceNormal * 0.05f;
        if (!surfaceNormal.IsEqualApprox(Vector3.Up))
        {
            // ATASCO #9: si la normal es paralela al up, LookAt dispara
            // 'Up vector and direction are aligned'. Ocurre en suelo (normal +Y)
            // y en TECHO (normal -Y): -surfaceNormal queda paralelo a +Y.
            // Usamos un up alternativo cuando la normal casi se alinea con +Y.
            Vector3 up = Mathf.Abs(surfaceNormal.Dot(Vector3.Up)) < 0.99f ? Vector3.Up : Vector3.Forward;
            LookAtFromPosition(GlobalPosition, GlobalPosition - surfaceNormal, up);
            RotateObjectLocal(Vector3.Right, -Mathf.Pi / 2f); // -Z -> -Y
        }
        AlbedoMix = 1.0f;
        Modulate = new Color(1, 1, 1, (float)GD.RandRange(0.7, 1.0));
        Size = new Vector3((float)GD.RandRange(0.4, 0.8), 1.0f, (float)GD.RandRange(0.4, 0.8));
        DistanceFadeEnabled = true;

        var t = CreateTween();
        t.TweenInterval(Lifetime);
        t.TweenProperty(this, "modulate:a", 0.0f, FadeSeconds);
        t.TweenCallback(Callable.From(QueueFree));
    }
}
