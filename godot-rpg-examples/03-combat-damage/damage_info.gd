# damage_info.gd
# Recurso serializable que describe un golpe. Editable como .tres en el inspector.
# Godot 4.6 - GDScript 2.0. Reutiliza Resource en vez de structs/clases ad hoc.
class_name DamageInfo
extends Resource

## Cantidad de daño base antes de resistencias.
@export var amount: float = 10.0
## Tipo de daño (StringName para comparaciones rapidas y sin asignaciones).
@export var type: StringName = &"physical"
## Fuerza del empuje aplicado al receptor.
@export var knockback: float = 6.0
## Multiplicadores por tipo de dano del receptor (typed dictionary 4.6).
@export var resistances: Dictionary[StringName, float] = {}

## Quien inflige el golpe. Asignado en runtime; no se exporta ni se serializa.
var source: Node3D
