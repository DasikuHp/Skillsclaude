# stat.gd
# Un stat individual (HP max, fuerza, defensa...) como Resource.
# Mantiene un base_value y una lista de StatModifier, y recalcula value()
# con un orden de operaciones explicito. Emite stat_updated (senal propia,
# NO la heredada `changed`, que no se emite de forma fiable por codigo:
# https://github.com/godotengine/godot/issues/30179).
# Godot 4.6 / GDScript 2.0.
class_name Stat
extends Resource

signal stat_updated

@export var base_value: float = 0.0

# Los modificadores NO van en @export para controlarlos en runtime; si los
# expusieras dentro de un Array, recuerda que duplicate(true) NO los copia en
# profundidad (https://github.com/godotengine/godot/issues/74918).
var _modifiers: Array[StatModifier] = []

func value() -> float:
	var flat := base_value
	var percent := 0.0
	var mult := 1.0
	for m: StatModifier in _modifiers:
		match m.modifier_type:
			StatModifier.Type.ADD:         flat += m.amount
			StatModifier.Type.PERCENT_ADD: percent += m.amount
			StatModifier.Type.MULT:        mult *= m.amount
	# Orden: ADD -> (1 + suma de PERCENT_ADD) -> MULT en cascada.
	return flat * (1.0 + percent) * mult

func add_modifier(m: StatModifier) -> void:
	_modifiers.append(m)
	stat_updated.emit()

func remove_modifier(m: StatModifier) -> void:
	if _modifiers.erase(m):
		stat_updated.emit()

func remove_modifiers_from(src: StringName) -> void:
	var removed := false
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].source == src:
			_modifiers.remove_at(i)
			removed = true
	if removed:
		stat_updated.emit()
