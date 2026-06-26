extends Node3D

# La clase nativa Example aparece en "Create New Node" y se usa como cualquier nodo,
# pero el editor debe haber abierto/importado el proyecto una vez para registrarla.
# Headless:  godot --headless --import --path .

@onready var ex: Example = $Example   # tipo nativo, autocompleta tras importar

func _ready() -> void:
    ex.speed = 5.0                              # property bindeada
    print(ex.get_speed())

    var data: PackedInt32Array = [1, 2, 3, 4]
    print(ex.sum_hot_loop(data))                # 10, ejecutado en C++ nativo

    # Instanciacion en codigo, identica a un Node nativo:
    var e := Example.new()
    e.speed = 2.0
    add_child(e)
