extends Node
## Autoload "SaveManager" — sistema de guardado por slots para un RPG 3D (Godot 4.6).
##
## Filosofia: el progreso del jugador se persiste como JSON plano bajo user://,
## SIN serializar objetos ni Resources (evita el vector de ejecucion de codigo).
## Settings (audio/video/keybinds) van por separado en ConfigFile.
##
## Registralo en Project Settings > Autoload con el nombre "SaveManager".

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_failed(slot: int, error: Error)

const SAVE_VERSION := 2
const SAVE_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.cfg"


func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


## Guarda el progreso del jugador como JSON plano.
func save_game(slot: int, player: Node3D, quests: Dictionary[StringName, int]) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var pos := player.global_position
	var data: Dictionary[String, Variant] = {
		"version": SAVE_VERSION,
		"player": {
			"hp": 80,
			# Vector3 no es JSON-nativo: se serializa como array de 3 floats.
			"pos": [pos.x, pos.y, pos.z],
		},
		"quests": quests,
	}

	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		push_error("No se pudo abrir el save: %s" % error_string(err))
		save_failed.emit(slot, err)
		return err

	f.store_string(JSON.stringify(data, "\t"))
	f.close() # explicito; tambien cerraria al salir de scope (RefCounted)
	game_saved.emit(slot)
	return OK


## Carga y migra un slot. Devuelve {} si no existe o esta corrupto.
func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo leer el slot %d" % slot)
		return {}

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		push_warning("Save corrupto en slot %d" % slot)
		return {}

	var data: Dictionary = _migrate(parsed)
	game_loaded.emit(slot)
	return data


## Reconstruye un Vector3 desde el array [x, y, z] guardado.
func read_position(data: Dictionary) -> Vector3:
	var player: Dictionary = data.get("player", {})
	var arr: Array = player.get("pos", [0.0, 0.0, 0.0])
	return Vector3(arr[0], arr[1], arr[2])


## Migracion por version. Gotcha: JSON devuelve TODO numero como float -> int().
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	if v < 2:
		# v1 no tenia "quests"; rellena el default y sube la version.
		data["quests"] = {}
		data["version"] = 2
	return data


## Settings via ConfigFile. Siempre pasa el 3.º argumento (default) en get_value.
func save_settings(master_volume: float, fullscreen: bool) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	return cfg.save(SETTINGS_PATH)


func load_settings() -> Dictionary[String, Variant]:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return {"master_volume": 1.0, "fullscreen": false}
	return {
		"master_volume": cfg.get_value("audio", "master_volume", 1.0),
		"fullscreen": cfg.get_value("video", "fullscreen", false),
	}
