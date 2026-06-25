using Godot;

// Stats.cs
// Equivalente C# (.NET 8) del sistema de stats desacoplado.
// Registrar como autoload "Stats".
public partial class Stats : Node
{
    [Signal]
    public delegate void HealthChangedEventHandler(int current, int maximum);

    [Signal]
    public delegate void ManaChangedEventHandler(int current, int maximum);

    [Export] public int MaxHealth { get; set; } = 100;
    [Export] public int MaxMana { get; set; } = 50;

    private int _health = 100;
    private int _mana = 50;

    public override void _Ready()
    {
        _health = MaxHealth;
        _mana = MaxMana;
        EmitSignal(SignalName.HealthChanged, _health, MaxHealth);
        EmitSignal(SignalName.ManaChanged, _mana, MaxMana);
    }

    public void TakeDamage(int amount)
    {
        _health = Mathf.Clamp(_health - amount, 0, MaxHealth);
        EmitSignal(SignalName.HealthChanged, _health, MaxHealth);
    }

    public bool SpendMana(int amount)
    {
        if (_mana < amount)
            return false;
        _mana = Mathf.Clamp(_mana - amount, 0, MaxMana);
        EmitSignal(SignalName.ManaChanged, _mana, MaxMana);
        return true;
    }
}
