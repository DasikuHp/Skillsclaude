@tool
extends EditorNode3DGizmoPlugin
class_name DungeonRoomGizmo
## Gizmo 3D persistente. Solo se registra desde un EditorPlugin vía
## add_node_3d_gizmo_plugin(DungeonRoomGizmo.new()). Compile-ready en 4.6.
## Sin _has_gizmo() devolviendo true, el gizmo NUNCA se dibuja y no hay error.

func _init() -> void:
	create_material("lines", Color.CYAN)

func _get_gizmo_name() -> String:
	return "DungeonRoom"

func _has_gizmo(node: Node3D) -> bool:
	return node is DungeonGrid          # decide qué nodos reciben el gizmo

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var lines := PackedVector3Array([Vector3.ZERO, Vector3.UP * 5.0])
	gizmo.add_lines(lines, get_material("lines", gizmo))
