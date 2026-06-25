extends MeshInstance3D
## Hit-flash multi-enemigo SIN parpadear toda la horda.
## Clave: set_instance_shader_parameter() actua por-MeshInstance3D, NO sobre
## el recurso ShaderMaterial compartido. Asi 30 enemigos comparten el .tres
## y solo el golpeado parpadea.

func hit() -> void:
	set_instance_shader_parameter("flash", 1.0)
	var t: Tween = create_tween()
	# tween_method evita la trampa de la property path "shader_parameter/...":
	# aqui llamamos al setter por instancia, no al recurso.
	t.tween_method(
		func(v: float) -> void: set_instance_shader_parameter("flash", v),
		1.0, 0.0, 0.15
	)
