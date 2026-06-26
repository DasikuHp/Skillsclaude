# health_component.gd
# Componente reutilizable de vida + i-frames + knockback.
# Anclalo como hijo de un CharacterBody3D (su owner) y conecta sus senales a la UI/IA.
class_name HealthComponent
extends Node

signal died
signal health_changed(current: float, max_value: float)

@export var max_health: float = 100.0
@export var iframe_time: float = 0.6

@onready var _iframes: Timer = $IFrameTimer

var _health: float

func _ready() -> void:
	_health = max_health
	_iframes.one_shot = true

## Metodo pato: lo invocan hitboxes/hitscan sin referencias duras.
func take_damage(info: DamageInfo) -> void:
	if not _iframes.is_stopped():
		return                                  # invulnerable durante i-frames
	var mult: float = info.resistances.get(info.type, 1.0)
	_health = maxf(_health - info.amount * mult, 0.0)
	health_changed.emit(_health, max_health)
	_apply_knockback(info)
	_iframes.start(iframe_time)
	if _health <= 0.0:
		died.emit()

func _apply_knockback(info: DamageInfo) -> void:
	var body := owner as CharacterBody3D
	if body == null or info.source == null:
		return
	var dir := body.global_position - info.source.global_position
	dir.y = 0.0
	body.velocity += dir.normalized() * info.knockback
