# dialogue_line.gd
# Godot 4.6 - Linea de dialogo como Resource recursivo (datos puros, sin nodos).
# Un arbol de dialogo ramificado se modela referenciando otros DialogueLine via @export.
# Para grafos con ciclos, prefiere next_id + un Dictionary en vez de @export directo.
class_name DialogueLine
extends Resource

@export var speaker: String = ""
@export_multiline var text: String = ""
## Vacio = avance lineal por next_line. Con elementos = se presentan al jugador.
@export var choices: Array[DialogueChoice] = []
## null = fin de la rama.
@export var next_line: DialogueLine
