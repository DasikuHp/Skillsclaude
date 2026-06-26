# ==========================================================
# GODOT 3 (MAL: no compila / parsea distinto en 4.6)
# ==========================================================
#
# tool
# extends Node
#
# signal died(score)
# export var hp = 100
# export(int, 0, 100) var armor
# onready var sprite = $Sprite
#
# func _ready():
#     connect("died", self, "_on_died")        # firma de 3 args (no existe)
#     emit_signal("died", 100)
#     yield(get_tree().create_timer(1.0), "timeout")
#     .ready()                                  # super con punto inicial
#
# func _on_died(score):
#     print(score)

# ==========================================================
# GODOT 4.6 (BIEN)
# ==========================================================
@tool
extends Node

signal died(score: int)                          # params tipados

@export var hp: int = 100
@export_range(0, 100) var armor: int = 0
@onready var sprite: Sprite2D = $Sprite2D        # se resuelve al entrar al arbol (no en _init)

func _ready() -> void:
    died.connect(_on_died)                       # Callable, sin string ni self
    died.emit(100)                               # .emit, NO emit_signal
    await get_tree().create_timer(1.0).timeout   # await + propiedad-senal
    super()                                       # super(), NO .ready()

func _on_died(score: int) -> void:
    print(score)
