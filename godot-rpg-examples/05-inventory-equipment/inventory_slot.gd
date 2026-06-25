# inventory_slot.gd
# Un slot de UI: arrastra su item y recibe drops usando los tres virtuales
# nativos de Control. Para un slot de equipo, fija slot_id (p.ej. &"HEAD");
# para un slot generico de inventario, deja slot_id = &"".
# Espera un hijo TextureRect llamado "Icon".
class_name InventorySlot
extends PanelContainer

@export var slot_id: StringName = &""   # &"" => acepta cualquier item
var item: ItemData

@onready var _icon: TextureRect = $Icon

func set_item(value: ItemData) -> void:
	item = value
	_icon.texture = item.icon if item != null else null

func clear() -> void:
	set_item(null)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	var preview := TextureRect.new()
	preview.texture = item.icon
	preview.custom_minimum_size = Vector2(48, 48)
	set_drag_preview(preview)
	return {&"source_slot": self, &"item": item}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has(&"item")):
		return false
	var dragged: ItemData = data[&"item"]
	# Slot de equipo: solo acepta el equip_slot correcto. Generico: acepta todo.
	return slot_id == &"" or dragged.equip_slot == slot_id

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source: InventorySlot = data[&"source_slot"]
	var dragged: ItemData = data[&"item"]
	source.clear()
	set_item(dragged)   # si slot_id != &"", aqui aplicarias dragged.modifiers a stats
