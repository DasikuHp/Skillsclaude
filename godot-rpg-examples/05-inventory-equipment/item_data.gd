# item_data.gd
# Blueprint de un item como Resource data-driven (Godot 4.6).
# Cada item concreto se guarda como un .tres: clic-derecho en FileSystem ->
# New Resource -> ItemData (aparece por tener class_name).
# El inventario guarda una REFERENCIA a este recurso + una cantidad,
# nunca un nodo ni una copia del blueprint.
class_name ItemData
extends Resource

@export var id: StringName = &""            # clave estable para BD / stacking
@export var display_name: String = ""
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var equip_slot: StringName = &""    # &"" si no es equipable
@export var modifiers: Dictionary[StringName, int] = {}  # stat -> bonus (4.6)
