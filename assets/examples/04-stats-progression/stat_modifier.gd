# stat_modifier.gd
# Modificador atómico de un Stat. Resource serializable (.tres) y duplicable.
# Tipos de modificador con orden de operaciones fijado por el consumidor (ver stat.gd):
#   ADD          -> suma plana al base_value
#   PERCENT_ADD  -> porcentajes que se AGREGAN entre si antes de aplicar
#   MULT         -> multiplicadores que se aplican al final, en cascada
# Godot 4.6 / GDScript 2.0.
class_name StatModifier
extends Resource

enum Type { ADD, PERCENT_ADD, MULT }

@export var modifier_type: Type = Type.ADD
@export var amount: float = 0.0
## Duracion en segundos. <= 0.0 significa permanente (no expira).
@export var duration: float = 0.0
## Origen opcional (id del buff/equipo) para poder retirar por fuente.
@export var source: StringName = &""

func is_temporary() -> bool:
	return duration > 0.0
