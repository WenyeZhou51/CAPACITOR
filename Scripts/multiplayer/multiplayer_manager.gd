extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"

var multiplayer_scene = preload("res://Scenes/multiplayer_player.tscn")

var _players_spawn_node: Node3D

func host_game():
	print("starting host")
	_players_spawn_node = get_tree().get_current_scene().get_node("players")
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	multiplayer.multiplayer_peer = server_peer
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	#multiplayer.peer_disconnected.connect(_del_player)
	
	_remove_singler_player()
	
	_add_player_to_game(1)
	
func join_game():
	print("starting join")
	
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	
	multiplayer.multiplayer_peer = client_peer
	
	_remove_singler_player()

func _add_player_to_game(id: int):
	print("player %s joined the game" % id)

	var player_to_add: CharacterBody3D = multiplayer_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	player_to_add.set_multiplayer_authority(id)

	var interact_label_node = get_node("/root/Level/UI/InteractLabel")
	player_to_add.interact_label = get_node("/root/Level/UI/InteractLabel")
	
	var start_room = get_tree().get_current_scene().get_node_or_null("NavigationRegion3D/DungeonGenerator3D/start_room")
	if start_room:
		print("Found start_room at position:", start_room.global_transform.origin)
		_players_spawn_node.global_position = start_room.global_transform.origin
		print("START GLOBAL POS ", _players_spawn_node.global_position)
	else:
		print("Error: start_room node not found, using default position")
		player_to_add.global_position = Vector3(0, 0, 0)  # Fallback position

	# Attach player to the spawn node
	if _players_spawn_node:
		_players_spawn_node.add_child(player_to_add, true)
	else:
		print("Error: '_players_spawn_node' is null")
		
	#_players_spawn_node.call_deferred("add_child", player_to_add)
	
	if multiplayer.is_server():
		rpc_id(id, "set_player_position", id, _players_spawn_node.global_position)
		
	
	
func _del_player(id: int):
	print("player %s left the game" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
		
	_players_spawn_node.get_node(str(id)).queue_free()

func _remove_singler_player():
	print("remove single player")
	var player_to_remove = get_tree().get_current_scene().get_node("Player")
	player_to_remove.queue_free()

@rpc
func set_player_position(player_id: int, position: Vector3):
	# Ensure this is called on the correct peer
	if player_id != multiplayer.get_unique_id():
		return
	_players_spawn_node = get_tree().get_current_scene().get_node("players")
	var player_node = _players_spawn_node.get_node_or_null(str(player_id))
	if player_node:
		player_node.global_position = position
		print("Set player %s position to %s" % [player_id, position])
	else:
		print("Player node %s not found to set position" % player_id)
