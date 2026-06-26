extends MeshInstance3D
## Hit-flash multi-enemigo SIN parpadear toda la horda.
## Clave: set_instance_shader_parameter() actua por-MeshInstance3D, NO sobre
## el recurso ShaderMaterial compartido. Asi 30 enemigos comparten el .tres
## y solo el golpeado parpadea.
##
## OJO WEB: los 'instance uniform' NO existen en el renderer Compatibility
## (= export web): el shader no compila (godot-proposals#6909). Si tu juego
## exporta a web, NO uses hit(): usa hit_web(), que duplica el ShaderMaterial
## por enemigo (resource_local_to_scene) y dispara con set_shader_parameter.

## Forward+/Mobile: por instancia, sin duplicar recurso.
func hit() -> void:
	set_instance_shader_parameter("flash", 1.0)
	var t: Tween = create_tween()
	# tween_method evita la trampa de la property path "shader_parameter/...":
	# aqui llamamos al setter por instancia, no al recurso.
	t.tween_method(
		func(v: float) -> void: set_instance_shader_parameter("flash", v),
		1.0, 0.0, 0.15
	)

## Web/Compatibility: material propio por enemigo (no hay instance uniform).
## Llama esto una vez en _ready() para aislar el material de este enemigo.
func make_material_unique() -> void:
	var mat: ShaderMaterial = get_active_material(0) as ShaderMaterial
	if mat != null:
		var copy: ShaderMaterial = mat.duplicate() as ShaderMaterial
		copy.resource_local_to_scene = true
		set_surface_override_material(0, copy)

## Web/Compatibility: el shader usa 'uniform float flash' (NO instance uniform).
func hit_web() -> void:
	var mat: ShaderMaterial = get_active_material(0) as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash", 1.0)
	var t: Tween = create_tween()
	t.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("flash", v),
		1.0, 0.0, 0.15
	)
