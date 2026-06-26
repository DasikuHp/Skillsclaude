# res://systems/inventory/item.gd
# Dato de RPG como Resource tipado, guardable en data/*.tres. @abstract (desde 4.5)
# evita instanciar la clase base por error: usa subclases concretas (Weapon, Potion...).
# NO pongas class_name + autoload en el mismo archivo: "Class X hides an autoload singleton".
@abstract
class_name Item
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_stack: int = 1
@export var icon: Texture2D

## Subclases definen el efecto al usar el item.
@abstract func use(target: Node) -> void
