@tool
extends Node3D
class_name DungeonRoom
## Tipo custom mínimo que registra plugin.gd vía add_custom_type (compile-ready en 4.6).
## Debe ser @tool: todo script usado por un EditorPlugin corre en el editor; sin @tool
## se comporta como archivo vacío. preload() en plugin.gd lo resuelve en PARSE time,
## así que este archivo DEBE existir o --check-only de plugin.gd falla al parsear.

@export_range(1, 32) var room_width: int = 8
@export_range(1, 32) var room_depth: int = 8
