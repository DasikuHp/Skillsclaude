# health_bar.gd
# Raiz: TextureProgressBar (deriva de Range) dentro de un CanvasLayer.
# Reacciona a Stats.health_changed y anima el valor con un Tween.
# No hay polling, no hay _process: pura reaccion a senal.
extends TextureProgressBar

@export var fill_time: float = 0.2

func _ready() -> void:
	Stats.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, maximum: int) -> void:
	max_value = maximum
	var tw: Tween = create_tween()
	tw.tween_property(self, "value", current, fill_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
