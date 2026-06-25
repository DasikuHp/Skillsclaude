# unit_stats.gd
# Hoja de stats completa de una unidad (jugador/enemigo) como Resource.
# Incluye: nivel/XP (umbral por FORMULA, no por Curve), crecimiento de HP por
# Curve (eje X normalizado a [0,1]), resistencias como Dictionary tipado, y
# senales propias para desacoplar la UI.
#
# IMPORTANTE (Godot 4.6): los Resource se comparten por referencia. Para que
# cada enemigo tenga su HP independiente, llama a setup_unique() en _ready()
# del nodo que lo posee (usa duplicate(true)).
# Refs: https://shaggydev.com/2026/04/08/godot-custom-resources/
#       https://github.com/godotengine/godot/issues/45350
class_name UnitStats
extends Resource

signal leveled_up(new_level: int)
signal xp_changed(current: int, required: int)
signal hp_changed(old_hp: int, new_hp: int)

@export var max_level: int = 50
## Curva de crecimiento de HP. Eje Y = HP; el eje X se sampleara normalizado.
@export var hp_curve: Curve
## Resistencias por tipo de dano. Negativo = vulnerabilidad.
@export var resistances: Dictionary[StringName, float] = {
	&"fire": 0.25,
	&"ice": -0.5,
}

@export var level: int = 1
@export var current_xp: int = 0

var current_hp: int = 0

func setup_unique() -> UnitStats:
	# Deep-duplicate para no compartir estado con otras instancias del .tres.
	var copy := duplicate(true) as UnitStats
	copy.current_hp = copy.max_hp_at(copy.level)
	return copy

func max_hp_at(lvl: int) -> int:
	if hp_curve == null:
		return 0
	if max_level <= 1:
		return int(round(hp_curve.sample_baked(0.0)))
	# Curve mapea X en [0,1] por defecto -> normalizamos el nivel.
	var t := clampf(float(lvl - 1) / float(max_level - 1), 0.0, 1.0)
	return int(round(hp_curve.sample_baked(t)))

func xp_for_next_level() -> int:
	# Umbral por formula (NO Curve): Curve no es una tabla por-nivel infinita.
	return int(100.0 * pow(level, 1.5))

func add_xp(amount: int) -> void:
	current_xp += amount
	# while (no if): una recompensa grande puede subir varios niveles de golpe.
	while level < max_level and current_xp >= xp_for_next_level():
		current_xp -= xp_for_next_level()
		level += 1
		var old_hp := current_hp
		current_hp = max_hp_at(level)   # refill al subir de nivel
		hp_changed.emit(old_hp, current_hp)
		leveled_up.emit(level)
	xp_changed.emit(current_xp, xp_for_next_level())

func apply_damage(amount: float, type: StringName) -> int:
	var resist := resistances.get(type, 0.0)
	var dealt := int(round(amount * (1.0 - resist)))
	var old_hp := current_hp
	current_hp = maxi(0, current_hp - dealt)
	hp_changed.emit(old_hp, current_hp)
	return dealt
