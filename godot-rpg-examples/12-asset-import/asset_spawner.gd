extends Node3D

# Ruta conocida en compile-time: preload valida en editor y es mas rapido.
# Cargas la ESCENA importada (PackedScene), nunca el .glb "crudo".
const EnemyScene: PackedScene = preload("res://assets/enemies/goblin.glb")

func spawn_static() -> Node3D:
	var enemy := EnemyScene.instantiate() as Node3D  # 4.x: instantiate(), NO instance()
	add_child(enemy)
	return enemy

# Ruta dinamica en runtime.
func spawn(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar PackedScene: %s" % path)
		return null
	var inst := packed.instantiate() as Node3D
	add_child(inst)
	return inst

# Override de material en runtime SIN tocar el import (material embebido = read-only).
func tint_enemy(inst: Node3D) -> void:
	var mesh := inst.get_node("Skeleton3D/Body") as MeshInstance3D
	var mat := preload("res://assets/materials/goblin_red.tres") as StandardMaterial3D
	mesh.set_surface_override_material(0, mat)

# En 4.6 los nombres de animacion del AnimationPlayer son StringName (GH-110767):
# usa literales &"..." para evitar friccion con tipado estricto.
func play_run(anim: AnimationPlayer) -> void:
	if anim.current_animation != &"locomotion/Run":
		anim.play(&"locomotion/Run")

# Carga asincrona para mundos grandes (evita stutter).
func request_async(path: String) -> void:
	ResourceLoader.load_threaded_request(path)

func poll_async(path: String) -> void:
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			add_child(packed.instantiate())
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Carga asincrona fallo: %s" % path)

# Importar un .glb arbitrario en runtime (mods/user-content). GLTFDocument funciona
# en exports; ResourceImporterScene es editor-only.
func load_external_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("Couldn't load glTF scene: %d" % err)
		return null
	# Con append_from_buffer debes setear state.base_path para texturas externas.
	return doc.generate_scene(state)
