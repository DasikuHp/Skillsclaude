// res://autoload/MusicManager.cs  (autoload; .NET 8, Godot 4.6)
// Recordatorio: C# NO funciona en export web (web = Compatibility, sin .NET).
// Si la skill necesita build web, usa la version GDScript.
using Godot;

public partial class MusicManager : Node
{
    private const float SilenceDb = -80.0f;
    private const float Fade = 1.5f;

    private readonly AudioStreamPlayer _a = new();
    private readonly AudioStreamPlayer _b = new();
    private AudioStreamPlayer _active;
    private Tween _tween;

    public override void _Ready()
    {
        foreach (AudioStreamPlayer p in new[] { _a, _b })
        {
            p.Bus = "Music";
            p.VolumeDb = SilenceDb;
            p.ProcessMode = ProcessModeEnum.Always;
            AddChild(p);
        }
        _active = _a;
    }

    public void PlayMusic(AudioStream stream, float fade = Fade)
    {
        if (_active.Stream == stream && _active.Playing)
            return; // misma pista sonando: no reiniciar
        AudioStreamPlayer next = _active == _a ? _b : _a;
        next.Stream = stream;
        next.VolumeDb = SilenceDb;
        next.Play();
        _tween?.Kill();
        AudioStreamPlayer prev = _active;
        _tween = CreateTween().SetParallel();
        // OJO: el property path es snake_case "volume_db", NO "VolumeDb".
        _tween.TweenProperty(next, "volume_db", 0.0f, fade);
        _tween.TweenProperty(prev, "volume_db", SilenceDb, fade);
        _tween.Chain().TweenCallback(Callable.From(prev.Stop));
        _active = next;
    }

    // Volumen de bus desde slider lineal [0,1].
    public static void SetBusVolume(string bus, float linear)
    {
        int i = AudioServer.GetBusIndex(bus);
        if (i == -1) { GD.PushWarning($"Bus inexistente: {bus}"); return; }
        AudioServer.SetBusVolumeLinear(i, linear); // 4.6: sin conversion manual
        // dB explicito: AudioServer.SetBusVolumeDb(i, linear > 0f ? Mathf.LinearToDb(linear) : -80f);
    }
}
