// res://autoload/SfxPool.cs  (autoload; .NET 8, Godot 4.6)
using Godot;

public partial class SfxPool : Node
{
    private readonly AudioStreamPlayer _player = new();
    private AudioStreamPlaybackPolyphonic _pb;

    public override void _Ready()
    {
        var poly = new AudioStreamPolyphonic { Polyphony = 32 };
        _player.Stream = poly;
        _player.Bus = "SFX";
        AddChild(_player);
        _player.Play(); // antes de GetStreamPlayback()
        _pb = (AudioStreamPlaybackPolyphonic)_player.GetStreamPlayback();
    }

    public void Play(AudioStream stream, float volDb = 0.0f, float pitch = 1.0f)
    {
        long id = _pb.PlayStream(stream, 0.0, volDb, pitch);
        if (id == AudioStreamPlaybackPolyphonic.InvalidId)
            GD.PushWarning("SFX pool lleno: subir Polyphony");
    }
}
