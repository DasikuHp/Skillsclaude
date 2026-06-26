# scene_manager.gd
# Autoload "SceneManager" para Godot 4.6.
# Centraliza transiciones de escena con fade (CanvasLayer + ColorRect + Tween)
# y carga threaded via ResourceLoader. Registrar en Project Settings -> Autoload
# con el nombre "SceneManager".
#
# Patron canonico de los docs de background_loading: request -> poll status -> get.
# Ver: https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html
extends Node

signal load_progress(value: float)   # 0.0..1.0, para alimentar una ProgressBar
signal load_finished

const FADE_TIME := 0.4

@export var fade_color: Color = Color.BLACK

var _target_path: String = ""
var _progress: Array = []             # array de salida para load_threaded_get_status
var _fade_rect: ColorRect

func _ready() -> void:
	set_process(false)
	_build_fade_overlay()

func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128                 # se dibuja por encima de todo
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = fade_color
	_fade_rect.color.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)

# Cambia a una escena por path, con fade-out -> carga threaded -> swap -> fade-in.
func change_scene(path: String) -> void:
	await _fade_to(1.0)               # pantalla negra
	_target_path = path
	var err := ResourceLoader.load_threaded_request(path)  # use_sub_threads = false (default)
	if err != OK:
		push_error("No se pudo pedir la carga de %s (err %d)" % [path, err])
		await _fade_to(0.0)
		return
	set_process(true)

func _process(_delta: float) -> void:
	if _target_path == "":
		return
	var status := ResourceLoader.load_threaded_get_status(_target_path, _progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var p: float = _progress[0] if not _progress.is_empty() else 0.0
			load_progress.emit(p)
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(_target_path)
			_target_path = ""
			set_process(false)
			get_tree().change_scene_to_packed(packed)
			load_finished.emit()
			await _fade_to(0.0)       # fade-in sobre la escena nueva
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Fallo cargando %s" % _target_path)
			_target_path = ""
			set_process(false)
			await _fade_to(0.0)

func _fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, FADE_TIME)
	await tween.finished
