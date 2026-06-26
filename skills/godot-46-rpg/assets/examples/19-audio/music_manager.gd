# res://autoload/music_manager.gd
# Autoload (Project Settings > Globals/Autoload, o en project.godot:
#   [autoload]
#   MusicManager="*res://autoload/music_manager.gd"   -> el '*' = enabled).
# La musica vive aqui, fuera del arbol que change_scene_to_* reemplaza.
extends Node

const SILENCE_DB := -80.0  # piso de silencio; NUNCA linear_to_db(0.0) = -inf
const FADE := 1.5

var _a := AudioStreamPlayer.new()
var _b := AudioStreamPlayer.new()
var _active: AudioStreamPlayer
var _tween: Tween

func _ready() -> void:
	for p: AudioStreamPlayer in [_a, _b]:
		p.bus = &"Music"  # el bus "Music" DEBE existir o cae silenciosamente a Master
		p.volume_db = SILENCE_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando durante el pause
		add_child(p)
	_active = _a
	assert(AudioServer.get_bus_index("Music") != -1,
		"Bus 'Music' inexistente -> fallback silencioso a Master")

# Crossfade con dos players (uno solo no puede fundir A->B a la vez).
func play_music(stream: AudioStream, fade: float = FADE) -> void:
	# Guarda: misma pista ya sonando -> NO reiniciar (evita corte por sala).
	if _active.stream == stream and _active.playing:
		return
	var nxt: AudioStreamPlayer = _b if _active == _a else _a
	nxt.stream = stream
	nxt.volume_db = SILENCE_DB
	nxt.play()
	if _tween:
		_tween.kill()
	var prev := _active
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(nxt, "volume_db", 0.0, fade)
	_tween.tween_property(prev, "volume_db", SILENCE_DB, fade)
	_tween.chain().tween_callback(prev.stop)  # parar SOLO al terminar el fade
	_active = nxt

# Volumen de bus desde slider lineal [0,1]. Dos rutas validas en 4.6:
func set_bus_volume(bus: StringName, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		push_warning("Bus inexistente: %s" % bus)
		return
	# Opcion A (4.6, mas simple, sin lio de dB):
	AudioServer.set_bus_volume_linear(i, linear)
	# Opcion B (dB explicito): floor en -80, nunca -inf.
	# AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)) if linear > 0.0 else SILENCE_DB)

# Ducking manual por Tween (predecible; alternativa al sidechain del Compressor).
func duck_music(target_db: float = -12.0, dur: float = 0.3) -> void:
	var i := AudioServer.get_bus_index("Music")
	if i == -1:
		return
	create_tween().tween_method(
		func(v: float) -> void: AudioServer.set_bus_volume_db(i, v),
		AudioServer.get_bus_volume_db(i), target_db, dur)
