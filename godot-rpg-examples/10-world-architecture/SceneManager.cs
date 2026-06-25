// SceneManager.cs
// Autoload "SceneManager" para Godot 4.6 con .NET 8.
// Equivalente idiomatico C# del flujo fade + carga threaded.
// Registrar en Project Settings -> Autoload.
//
// Gotchas 4.6 contemplados:
//  - useSubThreads se deja en false (default): true puede deadlock con C# (#103674).
//  - Para CallDeferred con parametros complejos usar Callable.From(() => ...).
//  - Recompilar al pasar 4.5 -> 4.6: nombres de track AnimationPlayer String -> StringName.
//  - C# no exporta a web en 4.6: si necesitas navegador, usa GDScript + Compatibility.
using Godot;

public partial class SceneManager : Node
{
    [Signal] public delegate void LoadProgressEventHandler(float value);
    [Signal] public delegate void LoadFinishedEventHandler();

    [Export] public Color FadeColor { get; set; } = Colors.Black;
    private const float FadeTime = 0.4f;

    private string _targetPath = "";
    private readonly Godot.Collections.Array _progress = new();
    private ColorRect _fadeRect = null!;

    public override void _Ready()
    {
        SetProcess(false);
        var layer = new CanvasLayer { Layer = 128 };
        AddChild(layer);
        _fadeRect = new ColorRect
        {
            Color = FadeColor with { A = 0f },
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        _fadeRect.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        layer.AddChild(_fadeRect);
    }

    public async void ChangeScene(string path)
    {
        await FadeTo(1.0f);
        _targetPath = path;
        Error err = ResourceLoader.LoadThreadedRequest(path); // useSubThreads: false (default)
        if (err != Error.Ok)
        {
            GD.PushError($"No se pudo pedir la carga de {path} (err {err})");
            await FadeTo(0.0f);
            return;
        }
        SetProcess(true);
    }

    public override void _Process(double delta)
    {
        if (_targetPath == "")
            return;

        var status = ResourceLoader.LoadThreadedGetStatus(_targetPath, _progress);
        switch (status)
        {
            case ResourceLoader.ThreadLoadStatus.InProgress:
                float p = _progress.Count > 0 ? (float)_progress[0] : 0f;
                EmitSignal(SignalName.LoadProgress, p);
                break;
            case ResourceLoader.ThreadLoadStatus.Loaded:
                var packed = (PackedScene)ResourceLoader.LoadThreadedGet(_targetPath);
                _targetPath = "";
                SetProcess(false);
                GetTree().ChangeSceneToPacked(packed);
                EmitSignal(SignalName.LoadFinished);
                FadeIn();
                break;
            case ResourceLoader.ThreadLoadStatus.Failed:
            case ResourceLoader.ThreadLoadStatus.InvalidResource:
                GD.PushError($"Fallo cargando {_targetPath}");
                _targetPath = "";
                SetProcess(false);
                FadeIn();
                break;
        }
    }

    private async void FadeIn() => await FadeTo(0.0f);

    private async System.Threading.Tasks.Task FadeTo(float targetAlpha)
    {
        Tween tween = CreateTween();
        tween.TweenProperty(_fadeRect, "color:a", targetAlpha, FadeTime);
        await ToSignal(tween, Tween.SignalName.Finished);
    }
}
