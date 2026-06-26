@tool
extends MultiMeshInstance3D
class_name PropScatter
## Decoración masiva (miles de instancias, un draw call). Compile-ready en 4.6.
## ORDEN CRÍTICO: transform_format -> mesh -> instance_count -> set_instance_transform.
## Cambiar instance_count DESPUÉS resetea todos los transforms.

@export var prop_mesh: Mesh
@export var instance_total: int = 500
@export var area_size: float = 20.0

@export_tool_button("Scatter", "MultiMeshInstance3D") var _go: Callable = scatter

func scatter() -> void:
	if prop_mesh == null:
		push_error("PropScatter: asigna 'prop_mesh'.")
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D    # 1) ANTES de instance_count
	mm.mesh = prop_mesh                              # 2) mesh
	mm.instance_count = instance_total              # 3) reserva (bloquea cambios de format)
	var rng := RandomNumberGenerator.new()
	for i in mm.instance_count:                      # 4) transforms al final
		var pos := Vector3(
			rng.randf_range(-area_size, area_size),
			0.0,
			rng.randf_range(-area_size, area_size))
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
	multimesh = mm
	assert(multimesh.instance_count == instance_total)
