# dialogue_choice.gd
# Godot 4.6 - Opcion de dialogo. La condicion es un string evaluado con Expression
# contra el diccionario de flags (ej. "flags.has(&\"talked_to_elder\")").
class_name DialogueChoice
extends Resource

@export var label: String = ""
@export var next_line: DialogueLine
## Vacio = siempre visible. Si no, se evalua con Expression.
@export var condition: String = ""
