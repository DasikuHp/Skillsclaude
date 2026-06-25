# inventory.gd
# Logica de inventario pura, sin UI. Es un Resource para poder guardarlo/cargarlo.
# Guarda referencia al blueprint (items) + cantidad (stacks).
class_name Inventory
extends Resource

signal changed

# id -> cantidad. Nota: este ejemplo minimo apila tambien los no-apilables por
# simplicidad (un unico contador por id). Para estado por instancia (durabilidad,
# encantamientos) guarda copias duplicate(true) en una coleccion aparte
# (Array[ItemData] o claves unicas por instancia): varias instancias colisionarian
# bajo la misma id.
@export var stacks: Dictionary[StringName, int] = {}
# id -> blueprint, para resolver icono/nombre sin volver a cargar el .tres.
@export var items: Dictionary[StringName, ItemData] = {}

func add_item(item: ItemData, amount: int = 1) -> int:
	items[item.id] = item
	if item.stackable:
		var current: int = stacks.get(item.id, 0)
		var allowed: int = mini(current + amount, item.max_stack)
		var added: int = allowed - current
		stacks[item.id] = allowed
		changed.emit()
		return added
	# No-apilable: en este ejemplo se cuenta igual por id (simplificacion intencional).
	stacks[item.id] = stacks.get(item.id, 0) + amount
	changed.emit()
	return amount

func remove_item(id: StringName, amount: int = 1) -> void:
	if not stacks.has(id):
		return
	stacks[id] = maxi(stacks[id] - amount, 0)
	if stacks[id] == 0:
		stacks.erase(id)
		items.erase(id)
	changed.emit()

func count(id: StringName) -> int:
	return stacks.get(id, 0)

func has_item(id: StringName) -> bool:
	return count(id) > 0
