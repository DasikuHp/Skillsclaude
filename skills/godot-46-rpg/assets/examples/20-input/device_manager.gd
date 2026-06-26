# Autoload "DeviceManager": detecta si el jugador usa teclado/raton o mando para
# cambiar los prompts de la UI (iconos WASD vs A/B/X/Y).
#
# CLAVE: se infiere del TIPO del ultimo InputEvent. NO uses event.device para esto:
# teclado, raton y el primer joypad TODOS son device 0 (GH-7161).
extends Node

enum Scheme { KEYBOARD_MOUSE, GAMEPAD }

var current: Scheme = Scheme.KEYBOARD_MOUSE
signal scheme_changed(new_scheme: Scheme)

const STICK_DEADZONE: float = 0.2  # ignora drift del stick para no flipear el icono

func _ready() -> void:
	for dev: int in Input.get_connected_joypads():
		print("Mando %d: %s (guid=%s)" % [dev, Input.get_joy_name(dev), Input.get_joy_guid(dev)])
	Input.joy_connection_changed.connect(_on_joy_changed)

func _on_joy_changed(device_id: int, connected: bool) -> void:
	print("device %d -> %s" % [device_id, "conectado" if connected else "desconectado"])

func _input(event: InputEvent) -> void:
	var detected: Scheme = current
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		detected = Scheme.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton:
		detected = Scheme.GAMEPAD
	elif event is InputEventJoypadMotion:
		# Sin este filtro, el stick en reposo cambia el esquema solo.
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
			detected = Scheme.GAMEPAD
	if detected != current:
		current = detected
		scheme_changed.emit(current)
