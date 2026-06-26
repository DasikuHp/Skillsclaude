# res://autoload/sfx.gd  (autoload "Sfx")
# Pool de SFX globales con AudioStreamPolyphonic: un nodo, N voces, sin instanciar.
# OJO: el polifonico NO emite 'finished' por stream (GH-88941). Si necesitas saber
# cuando termino UN disparo concreto, usa un pool de AudioStreamPlayer reusados.
extends Node

var _player := AudioStreamPlayer.new()
var _pb: AudioStreamPlaybackPolyphonic

func _ready() -> void:
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 32  # subir si play_stream() devuelve INVALID_ID
	_player.stream = poly
	_player.bus = &"SFX"
	add_child(_player)
	_player.play()  # IMPRESCINDIBLE antes de get_stream_playback()
	_pb = _player.get_stream_playback() as AudioStreamPlaybackPolyphonic

func play(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var id := _pb.play_stream(stream, 0.0, vol_db, pitch)
	if id == AudioStreamPlaybackPolyphonic.INVALID_ID:
		push_warning("SFX pool lleno: subir polyphony")
