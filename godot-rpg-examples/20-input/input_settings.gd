# Autoload llamado "InputSettings". Ponlo el PRIMERO en la lista de autoloads:
# Project > Project Settings > Globals/Autoload. Si carga despues de las escenas
# que ya leyeron el InputMap, los primeros frames usan los defaults de project.godot.
#
# Cubre: remapeo en runtime (captura + filtro echo/drift), persistencia a user://,
# reset a defaults. InputMap NO persiste solo: se resetea desde project.godot en cada
# arranque, asi que cargar aqui en _ready() es obligatorio.
extends Node

const SAVE_PATH: String = "user://keybinds.cfg"

# Solo acciones de gameplay; nunca toques las ui_* built-in.
const REMAPPABLE: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"attack", &"interact", &"dodge",
]

var _awaiting: StringName = &""
signal remap_finished(action: StringName)

func _ready() -> void:
	load_or_default()
	set_process_input(false)  # solo escuchamos durante un remapeo activo

# --- Remapeo en runtime ---------------------------------------------------

func start_remap(action: StringName) -> void:
	assert(InputMap.has_action(action), "Accion inexistente: %s" % action)
	_awaiting = action
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if _awaiting == &"":
		return
	# Acepta tecla / boton de raton / boton de mando / eje de mando con intencion clara.
	# Ignora echo (auto-repeat) y el drift del stick por debajo de 0.5.
	var valid: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	)
	if not valid:
		return

	InputMap.action_erase_events(_awaiting)   # plural: borra TODOS los eventos previos
	InputMap.action_add_event(_awaiting, event)
	Input.action_release(_awaiting)           # evita que quede "pegada" si la tecla seguia abajo (GH-63734)
	get_viewport().set_input_as_handled()     # no propagar al gameplay

	var done: StringName = _awaiting
	_awaiting = &""
	set_process_input(false)
	save()
	remap_finished.emit(done)

# --- Persistencia (ConfigFile con InputEvent Resources, via nativa) -------

func save() -> void:
	var cfg := ConfigFile.new()
	for action: StringName in REMAPPABLE:
		cfg.set_value("input", String(action), InputMap.action_get_events(action))
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("No se pudieron guardar los keybinds: %s" % error_string(err))

func load_or_default() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # primer arranque: mantiene los defaults de project.godot
	for action_str: String in cfg.get_section_keys("input"):
		var action := StringName(action_str)
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)  # OJO: default de add_action es 0.5
		InputMap.action_erase_events(action)
		for ev: InputEvent in cfg.get_value("input", action_str):
			InputMap.action_add_event(action, ev)

func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()  # descarta remapeo y recarga project.godot
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# --- Mostrar la tecla bajo el layout del jugador (AZERTY/QWERTZ) -----------

func label_for_first_event(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "Unset"
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		var key := ev as InputEventKey
		# physical_keycode (WASD fisico) -> tecla logica del layout actual.
		var logical: Key = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		if logical == KEY_NONE:  # GH-110751: devuelve 0 en macOS -> fallback
			logical = key.physical_keycode
		return OS.get_keycode_string(logical)
	return ev.as_text()
