using Godot;

// PauseMenu.cs
// Raiz: Control. Pone su ProcessMode en WhenPaused; el CanvasLayer padre
// debe estar en Always/WhenPaused o los botones quedan inclicables en pausa.
// Nota 4.5->4.6 (GH-110767): varias propiedades de nombre de animacion de
// AnimationPlayer pasaron de String a StringName (current_animation,
// assigned_animation, autoplay, get_queue() -> StringName[], y el parametro de
// current_animation_changed). Cambio incompatible a nivel de fuente: el codigo
// que LEE estas propiedades (p.ej. string a = player.CurrentAnimation) rompe;
// ajusta esos tipos a StringName/StringName[] y recompila.
public partial class PauseMenu : Control
{
    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.WhenPaused;
        Hide();
        WireFocus();
    }

    private void WireFocus()
    {
        string[] names = { "%Resume", "%Options", "%Quit" };
        var buttons = new Button[names.Length];
        for (int i = 0; i < names.Length; i++)
        {
            buttons[i] = GetNode<Button>(names[i]);
            buttons[i].FocusMode = FocusModeEnum.All;
        }
        for (int i = 0; i < buttons.Length; i++)
        {
            buttons[i].FocusNeighborBottom = buttons[(i + 1) % buttons.Length].GetPath();
            buttons[i].FocusNeighborTop = buttons[(i - 1 + buttons.Length) % buttons.Length].GetPath();
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("ui_cancel"))
        {
            bool paused = !GetTree().Paused;
            GetTree().Paused = paused;
            Visible = paused;
            if (paused)
                GetNode<Button>("%Resume").GrabFocus();
            GetViewport().SetInputAsHandled();
        }
    }

    private void OnResumePressed()
    {
        GetTree().Paused = false;
        Hide();
    }

    // En 4.6 usa los nombres con prefijo Theme (AddThemeStyleboxOverride),
    // no el viejo AddStyleboxOverride de mirrors antiguos del binding.
    public void ApplyDangerStyle(Panel panel)
    {
        var sb = new StyleBoxFlat { BgColor = new Color("8b1a1a") };
        panel.AddThemeStyleboxOverride("panel", sb);
        GetNode<Button>("%WarnButton").ThemeTypeVariation = "DangerButton";
    }
}
