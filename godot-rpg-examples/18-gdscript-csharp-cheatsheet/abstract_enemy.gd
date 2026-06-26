# @abstract desde Godot 4.5. Instanciar Enemy.new() lanza:
#   Cannot instantiate abstract class "Enemy".
@abstract class_name Enemy extends CharacterBody3D

@export var max_hp: int = 100
var hp: int

func _ready() -> void:
    hp = max_hp

@abstract func take_damage(amount: int) -> void   # los hijos DEBEN override

# --- subclase concreta ---
# class_name Goblin extends Enemy
# func take_damage(amount: int) -> void:
#     hp -= amount
#     super.take_damage(amount)   # super.metodo, NO .take_damage
