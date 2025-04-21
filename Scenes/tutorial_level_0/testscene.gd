extends Node3D

var multiplayer_scene = preload("res://Scenes/player.tscn")
var _players_spawn_node: Node3D
var ui
var count = 0;

func _ready() -> void:
	ui = $UI
	#GameState.initNewLevel(10 * MultiplayerManager.player_count);
	_players_spawn_node = get_tree().get_current_scene().get_node("players")
	
	if not multiplayer.is_server(): return
	for id in MultiplayerManager.players.keys():
		print_debug("spawning player " + str(id))
		_add_player_to_game(MultiplayerManager.players[id].id)
		count += 10

func _add_player_to_game(id: int):
	print_debug("Adding player with ID: " + str(id))
	if not _players_spawn_node:
		print_debug("ERROR: Could not find players spawn node")
		return
	var player_instance: Player = multiplayer_scene.instantiate()
	print_debug("Player instance created")
	player_instance.name = str(id)
	player_instance.set_color(id);
	var spawn_position = Vector3(0, 0, 100)
	
	var spawn_points = get_tree().get_nodes_in_group("player_spawn_point")
	if spawn_points.size() > 0:
		spawn_position = spawn_points[0].global_transform.origin
		#spawn_position.y += count - 5
		
		print("spawning at spawnpoint")
		print("spawn position", spawn_position)
		
	else:
		spawn_position = Vector3(33 + count, 16, -5) # Fallback
		print("player spawn not found")
		
	var tmp = spawn_position
	tmp.x += count
	
	_players_spawn_node.add_child(player_instance, true)
	player_instance.global_position = tmp
	print(player_instance.global_position, "an23")
	
	print_debug ("submitted name to ui for setup " + player_instance.name)
	if (not id == 1):
		ui.setup_player.rpc_id(id, player_instance.name)
	else:
		ui.setup_player(player_instance.name)
	
	
