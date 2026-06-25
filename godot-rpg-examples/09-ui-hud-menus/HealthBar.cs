using Godot;

// HealthBar.cs
// Raiz: TextureProgressBar. Escucha Stats.HealthChanged via evento tipado.
// Gotcha: TweenProperty toma la propiedad como ruta-string de Godot ("value"),
// no como miembro C#.
public partial class HealthBar : TextureProgressBar
{
    [Export] public float FillTime { get; set; } = 0.2f;

    public override void _Ready()
    {
        // El delegado [Signal] ...EventHandler genera el evento C# para +=.
        GetNode<Stats>("/root/Stats").HealthChanged += OnHealthChanged;
    }

    private void OnHealthChanged(int current, int maximum)
    {
        MaxValue = maximum;
        CreateTween()
            .TweenProperty(this, "value", current, FillTime)
            .SetTrans(Tween.TransitionType.Sine)
            .SetEase(Tween.EaseType.Out);
    }
}
