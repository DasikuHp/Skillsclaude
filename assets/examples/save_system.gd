extends Node
## Autoload "SaveSystem". Guarda IDS y datos planos en JSON en user://,
## NUNCA objetos Resource. Al cargar, busca los ids para reencontrar los Resources.

const PATH := "user://save.json"

func save_game(player: Node3D, inventory: Inventory) -> void:
	var data := {
		"player_pos": var_to_str(player.global_position),
		"inv": inventory.slots,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func load_game(player: Node3D, inventory: Inventory) -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data == null:
		return false
	player.global_position = str_to_var(data["player_pos"])
	inventory.slots.clear()
	for id: StringName in data["inv"]:
		inventory.slots[id] = int(data["inv"][id])
	inventory.changed.emit()
	return true
