class_name Stats
extends Resource
## Stats de combate como Resource. El daño es una función pura + señales.
## La barra de vida escucha `health_changed`; nada de un CombatManager omnisciente.

signal health_changed(current: int, max: int)
signal died

@export var max_health: int = 100
@export var attack: int = 10
@export var defense: int = 2

var health: int

func _init() -> void:
	health = max_health

func apply_damage(amount: int) -> int:
	var dealt := maxi(1, amount - defense)
	health = maxi(0, health - dealt)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
	return dealt

func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)
