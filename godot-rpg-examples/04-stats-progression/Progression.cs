// Progression.cs
// Equivalente C# (.NET 8) de la hoja de stats como Resource.
// Reglas Godot 4.6: clase `partial`, archivo propio con el nombre de la clase,
// hereda de Resource y marcada [GlobalClass] para aparecer en "New Resource".
// [Export] y [Signal] solo aceptan tipos Variant-compatibles (diagnostico
// GD0202): usa Godot.Collections.Dictionary, nunca System.Collections.Generic.
//
// Gotcha 4.6 (GH-110767): current_animation/assigned_animation/autoplay/get_queue de
// AnimationPlayer pasaron de String a StringName; leerlas como string rompe en compilacion.
// Emitir senales custom: usa EmitSignal(SignalName.X, ...) (Issue #82268).
using Godot;

[GlobalClass]
public partial class Progression : Resource
{
    [Signal] public delegate void LeveledUpEventHandler(int newLevel);
    [Signal] public delegate void XpChangedEventHandler(int current, int required);
    [Signal] public delegate void HpChangedEventHandler(int oldHp, int newHp);

    [Export] public int MaxLevel { get; set; } = 50;
    [Export] public Curve HpCurve { get; set; }
    [Export] public Godot.Collections.Dictionary<StringName, float> Resistances { get; set; } = new()
    {
        { new StringName("fire"), 0.25f },
        { new StringName("ice"), -0.5f },
    };

    [Export] public int Level { get; set; } = 1;
    [Export] public int CurrentXp { get; set; }

    public int CurrentHp { get; set; }

    public Progression SetupUnique()
    {
        var copy = (Progression)Duplicate(true);
        copy.CurrentHp = copy.MaxHpAt(copy.Level);
        return copy;
    }

    public int MaxHpAt(int level)
    {
        if (HpCurve == null)
            return 0;
        if (MaxLevel <= 1)
            return Mathf.RoundToInt(HpCurve.SampleBaked(0.0f));
        float t = Mathf.Clamp((float)(level - 1) / (MaxLevel - 1), 0.0f, 1.0f);
        return Mathf.RoundToInt(HpCurve.SampleBaked(t));
    }

    public int XpForNextLevel() => (int)(100.0 * Mathf.Pow(Level, 1.5));

    public void AddXp(int amount)
    {
        CurrentXp += amount;
        while (Level < MaxLevel && CurrentXp >= XpForNextLevel())
        {
            CurrentXp -= XpForNextLevel();
            Level += 1;
            int oldHp = CurrentHp;
            CurrentHp = MaxHpAt(Level);
            EmitSignal(SignalName.HpChanged, oldHp, CurrentHp);
            EmitSignal(SignalName.LeveledUp, Level);
        }
        EmitSignal(SignalName.XpChanged, CurrentXp, XpForNextLevel());
    }

    public int ApplyDamage(float amount, StringName type)
    {
        float resist = Resistances.TryGetValue(type, out float r) ? r : 0.0f;
        int dealt = Mathf.RoundToInt(amount * (1.0f - resist));
        int oldHp = CurrentHp;
        CurrentHp = Mathf.Max(0, CurrentHp - dealt);
        EmitSignal(SignalName.HpChanged, oldHp, CurrentHp);
        return dealt;
    }
}
