extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"
const DEBUG = true  # Toggle debug logging

var multiplayer_scene = preload("res://Scenes/multiplayer_player.tscn")
var _players_spawn_node: Node3D

func debug_log(message: String) -> void:
	if DEBUG:
		print("[MultiplayerManager][%d] %s" % [Time.get_ticks_msec(), message])

func host_game():
	debug_log("Starting host initialization")
	var server_peer = ENetMultiplayerPeer.new()
	var error = server_peer.create_server(SERVER_PORT, 4)  # Max 4 players

	if error != OK:
		debug_log("ERROR: Failed to create server: " + str(error))
		return

	debug_log("Server created successfully on port " + str(SERVER_PORT))
	get_tree().get_multiplayer().multiplayer_peer = server_peer

	# Connect multiplayer signals
	get_tree().get_multiplayer().peer_connected.connect(_on_peer_connected)
	get_tree().get_multiplayer().peer_disconnected.connect(_on_peer_disconnected)

	debug_log("Removing single player instance")
	_remove_singler_player()

	# Initialize host player (server is ID=1 by default in this scheme)
	debug_log("Initializing host player with ID 1")
	call_deferred("_add_player_to_game", 1)

func join_game():
	debug_log("Starting client initialization")
	var client_peer = ENetMultiplayerPeer.new()
	var error = client_peer.create_client(SERVER_IP, SERVER_PORT)

	if error != OK:
		debug_log("ERROR: Failed to create client: " + str(error))
		return

	debug_log("Client created successfully, attempting connection to " + SERVER_IP)
	get_tree().get_multiplayer().multiplayer_peer = client_peer

	debug_log("Removing single player instance")
	_remove_singler_player()

func _on_peer_connected(id: int):
	debug_log("Peer connected with ID: " + str(id))
	# Instead of spawning the player on the server, have the client create its local node
	if get_tree().get_multiplayer().is_server():
		debug_log("Server telling peer " + str(id) + " to create local player")
		rpc_id(id, "_rpc_create_player", id)

func _on_peer_disconnected(id: int):
	debug_log("Peer disconnected with ID: " + str(id))
	_del_player(id)

@rpc("any_peer")
func _rpc_create_player(new_peer_id: int):
	# Only create if our local unique_id == new_peer_id
	if get_tree().get_multiplayer().get_unique_id() == new_peer_id:
		debug_log("Creating local player, matching our ID=" + str(new_peer_id))
		_add_player_to_game(new_peer_id)

@rpc("authority", "reliable")
func sync_player_spawn(player_id: int, spawn_position: Vector3):
	debug_log("Syncing player " + str(player_id) + " position: " + str(spawn_position))
	var player_node = get_tree().get_current_scene().get_node_or_null("players/" + str(player_id))
	if player_node:
		player_node.global_position = spawn_position
		debug_log("Player position synced successfully")
	else:
		debug_log("ERROR: Could not find player node for sync")

func _add_player_to_game(id: int):
	debug_log("Adding player with ID: " + str(id))

	_players_spawn_node = get_tree().get_current_scene().get_node("players")
	if not _players_spawn_node:
		debug_log("ERROR: Could not find players spawn node")
		return

	var player_instance = multiplayer_scene.instantiate()
	debug_log("Player instance created")

	player_instance.player_id = id
	player_instance.name = str(id)
	player_instance.set_multiplayer_authority(id)
	debug_log("Player instance configured with ID: " + str(id))

	var start_room = get_tree().get_current_scene().get_node_or_null("NavigationRegion3D/DungeonGenerator3D/start_room")
	var spawn_position = Vector3(40, 45, 0)

	if start_room:
		spawn_position = start_room.global_transform.origin
		debug_log("Found start room position: " + str(spawn_position))
	else:
		debug_log("WARNING: No start room found, using default position")

	_players_spawn_node.add_child(player_instance, true)
	debug_log("Player added to scene tree")

	player_instance.global_position = spawn_position

	# If we are the server, tell everyone where to spawn this player
	if get_tree().get_multiplayer().is_server():
		debug_log("Broadcasting player position to all clients")
		rpc("sync_player_spawn", id, spawn_position)

func _del_player(id: int):
	debug_log("Attempting to remove player with ID: " + str(id))
	if not _players_spawn_node:
		debug_log("ERROR: Players spawn node not found")
		return
	if not _players_spawn_node.has_node(str(id)):
		debug_log("WARNING: Player node " + str(id) + " not found for deletion")
		return
	var player_node = _players_spawn_node.get_node(str(id))
	player_node.queue_free()
	debug_log("Player " + str(id) + " removed successfully")

func _remove_singler_player():
	debug_log("Removing single player instance")
	var player_to_remove = get_tree().get_current_scene().get_node_or_null("Player")
	if player_to_remove:
		player_to_remove.queue_free()
		debug_log("Single player instance removed")
	else:
		debug_log("WARNING: No single player instance found to remove")

func _process(_delta: float):
	if DEBUG and get_tree().get_multiplayer().has_multiplayer_peer():
		var peer = get_tree().get_multiplayer().multiplayer_peer
		if peer is ENetMultiplayerPeer:
			debug_log(
				"Network Status - Connected Peers: " + str(peer.get_connection_status()) +
				" | Host: " + str(get_tree().get_multiplayer().is_server()) +
				" | Unique ID: " + str(get_tree().get_multiplayer().get_unique_id())
			)
