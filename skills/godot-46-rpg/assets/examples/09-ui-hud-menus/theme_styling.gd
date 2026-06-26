# theme_styling.gd
# Demuestra theme overrides por nodo y theme type variations en Godot 4.6.
# Reusa looks disenados en un Theme en vez de duplicar recursos Theme enteros.
extends Panel

# Mapeo tipado de roles logicos -> variaciones de tipo definidas en el Theme.
var _variants: Dictionary[StringName, StringName] = {
	&"danger": &"DangerButton",
	&"primary": &"PrimaryButton",
}

func _ready() -> void:
	# Override puntual de StyleBox para este Panel.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("8b1a1a")
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	add_theme_stylebox_override("panel", sb)

	# Reusar un look del Theme por nombre, sin codigo de estilo extra.
	if has_node("WarnButton"):
		($WarnButton as Button).theme_type_variation = _variants[&"danger"]
