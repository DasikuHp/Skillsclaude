// ItemData.cs
// Blueprint de item como Resource en C# (.NET 8, Godot 4.6).
// [GlobalClass] hace que aparezca en el dialogo New Resource (equivale a class_name).
// Usa Godot.Collections (no System.Collections.Generic) para tipos que cruzan Variant.
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class ItemData : Resource
{
    [Export] public StringName Id { get; set; } = "";
    [Export] public string DisplayName { get; set; } = "";
    [Export] public Texture2D Icon { get; set; }
    [Export] public bool Stackable { get; set; } = true;
    [Export] public int MaxStack { get; set; } = 99;
    [Export] public StringName EquipSlot { get; set; } = ""; // "" si no es equipable
    [Export] public Dictionary<StringName, int> Modifiers { get; set; } = new();
}
