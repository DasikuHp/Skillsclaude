# pause_menu.gd
# Raiz: Control con process_mode = PROCESS_MODE_WHEN_PAUSED en el Inspector.
# El CanvasLayer padre debe estar en PROCESS_MODE_ALWAYS o WHEN_PAUSED,
# o los botones quedaran inclicables durante la pausa.
# Botones esperados (unique names): %Resume, %Options, %Quit.
extends Control

func _ready() -> void:
	hide()
	_wire_focus()

func _wire_focus() -> void:
	# Cableado explicito de foco para una columna navegable con gamepad.
	# Util cuando el algoritmo espacial se equivoca con paneles superpuestos.
	var buttons: Array[Button] = [%Resume, %Options, %Quit]
	for i in buttons.size():
		buttons[i].focus_mode = Control.FOCUS_ALL
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_top = buttons[(i - 1) % buttons.size()].get_path()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var paused: bool = not get_tree().paused
		get_tree().paused = paused
		visible = paused
		if paused:
			(%Resume as Button).grab_focus()  # sin esto el gamepad no navega
		get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()

func _on_quit_pressed() -> void:
	get_tree().quit()
