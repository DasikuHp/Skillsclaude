# Compile-ready en Godot 4.6: valida con
#   godot --headless --check-only --script res://typed_signals_demo.gd
extends Node

signal died(score: int)

static var instances: int = 0                    # static var (4.6)

var loot: Array[String] = []                     # array tipado
var stats: Dictionary[String, int] = {"atk": 10} # Dictionary[K,V] (desde 4.4)

func _init() -> void:
    instances += 1

func _ready() -> void:
    # Senales: connect con Callable, lambda y bind
    died.connect(_on_died)
    died.connect(func(s: int): print("lambda: ", s))
    died.connect(_on_died_extra.bind("boss"))

    # StringName & NodePath literales
    if Input.is_action_just_pressed(&"attack"):
        var player := get_node(^"../Player")
        print(player)

    # Asignar array sin tipo a uno tipado: usar .assign(), no '='
    var raw := ["sword", "shield"]
    loot.assign(raw)

    # emit() devuelve void: NO es awaitable. await espera la PROXIMA emision.
    died.emit(42)

func _on_died(score: int) -> void:
    print("murio con ", score)

func _on_died_extra(score: int, who: String) -> void:
    print(who, " murio con ", score)
