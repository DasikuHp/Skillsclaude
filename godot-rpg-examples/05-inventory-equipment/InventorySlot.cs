// InventorySlot.cs
// Slot de UI con drag-and-drop nativo en C#. Espera un hijo TextureRect "Icon".
// Gotchas 4.6:
//  - _GetDragData devuelve Variant NO anulable: usa `default`, no `null` (issue #78507).
//  - Usa Godot.Collections.Dictionary, no System.*, y lee con .As<T>().
//  - Tras actualizar a 4.6, recompila por el cambio String->StringName en
//    nombres de pista de AnimationPlayer si tu UI dispara animaciones por nombre.
using Godot;
using Godot.Collections;

public partial class InventorySlot : PanelContainer
{
    [Export] public StringName SlotId { get; set; } = "";
    [Signal] public delegate void ChangedEventHandler();

    private TextureRect _icon;
    public ItemData Item { get; private set; }

    public override void _Ready() => _icon = GetNode<TextureRect>("Icon");

    public void SetItem(ItemData value)
    {
        Item = value;
        _icon.Texture = value?.Icon;
        EmitSignal(SignalName.Changed);
    }

    public void Clear() => SetItem(null);

    public override Variant _GetDragData(Vector2 atPosition)
    {
        if (Item == null)
            return default; // "sin datos": NO null (Variant es no anulable)

        var preview = new TextureRect
        {
            Texture = Item.Icon,
            CustomMinimumSize = new Vector2(48, 48),
        };
        SetDragPreview(preview);

        var data = new Dictionary
        {
            { "source_slot", this },
            { "item", Item },
        };
        return data; // Dictionary -> Variant implicito
    }

    public override bool _CanDropData(Vector2 atPosition, Variant data)
    {
        var dict = data.As<Dictionary>();
        if (dict == null || !dict.ContainsKey("item"))
            return false;

        var dragged = dict["item"].As<ItemData>();
        return SlotId == "" || dragged.EquipSlot == SlotId;
    }

    public override void _DropData(Vector2 atPosition, Variant data)
    {
        var dict = data.As<Dictionary>();
        var source = dict["source_slot"].As<InventorySlot>();
        var dragged = dict["item"].As<ItemData>();
        source.Clear();
        SetItem(dragged); // aqui aplicarias dragged.Modifiers a tus stats
    }
}
