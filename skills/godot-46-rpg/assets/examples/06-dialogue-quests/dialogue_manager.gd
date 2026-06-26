# dialogue_manager.gd
# Godot 4.6 - Autoload "Dialogue". Registrar en Project Settings -> Autoload.
# El manager NO conoce la UI: solo emite senales. La UI escucha y pinta.
# El estado (flags) vive aqui, nunca en nodos de escena (se perderian al recargar).
extends Node

signal line_displayed(line: DialogueLine)
signal choices_presented(choices: Array[DialogueChoice])
signal dialogue_ended

## Flags de conversacion/mundo (typed dictionary 4.6).
var flags: Dictionary[StringName, bool] = {}

func start(line: DialogueLine) -> void:
	_advance(line)

func _advance(line: DialogueLine) -> void:
	if line == null:
		dialogue_ended.emit()
		return
	line_displayed.emit(line)
	var available := _filter(line.choices)
	if not available.is_empty():
		choices_presented.emit(available)

## Llamado por la UI cuando el jugador elige una opcion.
func choose(choice: DialogueChoice) -> void:
	_advance(choice.next_line)

## Llamado por la UI para avanzar una linea sin opciones.
func continue_line(line: DialogueLine) -> void:
	_advance(line.next_line)

func set_flag(key: StringName, value: bool = true) -> void:
	flags[key] = value

func _filter(choices: Array[DialogueChoice]) -> Array[DialogueChoice]:
	var out: Array[DialogueChoice] = []
	for c in choices:
		if c.condition.is_empty() or _eval(c.condition):
			out.append(c)
	return out

func _eval(condition: String) -> bool:
	var expr := Expression.new()
	if expr.parse(condition, ["flags"]) != OK:
		push_warning("Condicion invalida: %s" % condition)
		return false
	var result: Variant = expr.execute([flags], self)
	if expr.has_execute_failed():
		push_warning("Fallo al evaluar: %s" % condition)
		return false
	return bool(result)
