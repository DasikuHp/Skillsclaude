class_name Inventory
extends Resource
## Inventario = datos puros + señal. La UI escucha `changed` y se reconstruye.
## Diccionario tipado (Godot 4.4+): id -> cantidad. La señal ES el pegamento.

signal changed

@export var slots: Dictionary[StringName, int] = {}

func add(id: StringName, n: int = 1) -> void:
	slots[id] = slots.get(id, 0) + n
	changed.emit()

func remove(id: StringName, n: int = 1) -> bool:
	if slots.get(id, 0) < n:
		return false
	slots[id] -= n
	if slots[id] <= 0:
		slots.erase(id)
	changed.emit()
	return true

func count(id: StringName) -> int:
	return slots.get(id, 0)
