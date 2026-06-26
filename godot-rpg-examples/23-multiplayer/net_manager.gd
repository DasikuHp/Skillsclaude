extends Node
## Listen-server co-op manager. Host es server + jugador (peer id 1).
## Compile-ready en Godot 4.6. Espera un nodo hermano:
##   ../Players  (Node contenedor)  y  $MultiplayerSpawner

const PORT := 7777
const MAX_CLIENTS := 8

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
	spawner.spawn_path = ^"../Players"
	spawner.spawn_function = _spawn_player
	# Señales de la API (NO del peer): RPCs no funcionan en señales del peer (GH-68750)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void:
		print("connected, my id=", multiplayer.get_unique_id()))
	multiplayer.connection_failed.connect(func() -> void:
		push_error("connection_failed"))
	multiplayer.server_disconnected.connect(func() -> void:
		push_error("server gone"))

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("create_server failed: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	_add_player(1)  # peer_connected NO dispara para el id propio

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)  # "127.0.0.1" en local, no "localhost"
	if err != OK:
		push_error("create_client failed: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():  # gate obligatorio: evita spawns dobles
		_add_player(id)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		var players := get_node(^"../Players")
		if players.has_node(str(id)):
			players.get_node(str(id)).queue_free()

func _add_player(id: int) -> void:
	if multiplayer.is_server():
		spawner.spawn(id)  # 'id' viaja como data a _spawn_player en TODOS los peers

func _spawn_player(data: int) -> Node:  # corre en cada peer
	var p := preload("res://player.tscn").instantiate()
	p.name = str(data)  # nombre determinista -> autoridad en _enter_tree
	return p            # NO add_child: el spawner lo añade bajo spawn_path
