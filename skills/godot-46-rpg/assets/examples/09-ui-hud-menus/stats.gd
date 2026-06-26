# stats.gd
# Sistema de stats desacoplado para un RPG 3D en Godot 4.6.
# Registrar como autoload con nombre "Stats", o usar como componente del jugador.
# El HUD nunca consulta estos valores: solo escucha las senales.
extends Node

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)

@export var max_health: int = 100
@export var max_mana: int = 50

var _health: int = 100
var _mana: int = 50

func _ready() -> void:
	_health = max_health
	_mana = max_mana
	health_changed.emit(_health, max_health)
	mana_changed.emit(_mana, max_mana)

func take_damage(amount: int) -> void:
	_health = clampi(_health - amount, 0, max_health)
	health_changed.emit(_health, max_health)

func heal(amount: int) -> void:
	_health = clampi(_health + amount, 0, max_health)
	health_changed.emit(_health, max_health)

func spend_mana(amount: int) -> bool:
	if _mana < amount:
		return false
	_mana = clampi(_mana - amount, 0, max_mana)
	mana_changed.emit(_mana, max_mana)
	return true
