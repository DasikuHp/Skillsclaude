class_name ItemData
extends Resource
## Un item es DATO puro: se edita en el Inspector, se duplica barato.
## Solo el pickup físico en el mundo es un nodo (campo `scene`).

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var max_stack: int = 99
@export var value: int = 0
@export var scene: PackedScene  # opcional: instancia del objeto soltado en el mundo
