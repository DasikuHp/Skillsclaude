// Autoload C# equivalente (remapeo + persistencia + deteccion de dispositivo).
// Recuerda: en export Web (Compatibility) NO hay C#/.NET -> si tu RPG va a web,
// usa la version GDScript para el menu de rebind.
// APIs en PascalCase; InputMap es estatico (no se instancia).
using Godot;

public partial class InputSettings : Node
{
    private const string SavePath = "user://keybinds.cfg";

    private static readonly StringName[] Remappable =
    {
        "move_left", "move_right", "move_forward", "move_back",
        "attack", "interact", "dodge",
    };

    public enum Scheme { KeyboardMouse, Gamepad }

    [Signal] public delegate void SchemeChangedEventHandler(int newScheme);
    [Signal] public delegate void RemapFinishedEventHandler(StringName action);

    private StringName _awaiting = null;
    private Scheme _scheme = Scheme.KeyboardMouse;
    private const float StickDeadzone = 0.2f;

    public override void _Ready()
    {
        LoadOrDefault();
        SetProcessInput(false);
    }

    // --- Remapeo en runtime -----------------------------------------------

    public void StartRemap(StringName action)
    {
        _awaiting = action;
        SetProcessInput(true);
    }

    public override void _Input(InputEvent @event)
    {
        // Deteccion de esquema (siempre activa via el mismo callback).
        Scheme next = _scheme;
        if (@event is InputEventKey or InputEventMouseButton or InputEventMouseMotion)
            next = Scheme.KeyboardMouse;
        else if (@event is InputEventJoypadButton)
            next = Scheme.Gamepad;
        else if (@event is InputEventJoypadMotion jm && Mathf.Abs(jm.AxisValue) > StickDeadzone)
            next = Scheme.Gamepad;
        if (next != _scheme)
        {
            _scheme = next;
            EmitSignal(SignalName.SchemeChanged, (int)next);
        }

        if (_awaiting is null)
            return;

        bool valid =
            (@event is InputEventKey k && k.Pressed && !k.Echo) ||
            (@event is InputEventMouseButton mb && mb.Pressed) ||
            (@event is InputEventJoypadButton jb && jb.Pressed) ||
            (@event is InputEventJoypadMotion m && Mathf.Abs(m.AxisValue) > 0.5f);
        if (!valid)
            return;

        InputMap.ActionEraseEvents(_awaiting);
        InputMap.ActionAddEvent(_awaiting, @event);
        Input.ActionRelease(_awaiting);
        GetViewport().SetInputAsHandled();

        StringName done = _awaiting;
        _awaiting = null;
        SetProcessInput(false);
        Save();
        EmitSignal(SignalName.RemapFinished, done);
    }

    // --- Persistencia ------------------------------------------------------

    public void Save()
    {
        var cfg = new ConfigFile();
        foreach (StringName action in Remappable)
            cfg.SetValue("input", action, InputMap.ActionGetEvents(action));
        Error err = cfg.Save(SavePath);
        if (err != Error.Ok)
            GD.PushWarning($"No se pudieron guardar los keybinds: {err}");
    }

    public void LoadOrDefault()
    {
        var cfg = new ConfigFile();
        if (cfg.Load(SavePath) != Error.Ok)
            return; // primer arranque: defaults de project.godot
        foreach (string actionStr in cfg.GetSectionKeys("input"))
        {
            var action = new StringName(actionStr);
            if (!InputMap.HasAction(action))
                InputMap.AddAction(action, 0.2f); // default de AddAction es 0.2f desde 4.4; explícito igualmente
            InputMap.ActionEraseEvents(action);
            // OJO: castea o lanza InvalidCastException.
            foreach (InputEvent ev in (Godot.Collections.Array<InputEvent>)cfg.GetValue("input", actionStr))
                InputMap.ActionAddEvent(action, ev);
        }
    }

    public void ResetToDefaults()
    {
        InputMap.LoadFromProjectSettings();
    }
}
