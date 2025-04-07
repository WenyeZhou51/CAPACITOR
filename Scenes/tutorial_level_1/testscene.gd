extends Node3D

var multiplayer_scene = preload("res://Scenes/player.tscn")
var _players_spawn_node: Node3D
var ui

func _ready() -> void:
	ui = $UI
	_players_spawn_node = get_tree().get_current_scene().get_node("players")
	GameState.initNewLevel(GameState._quota);
	GameState.alive_count = MultiplayerManager.player_count
	$NavigationRegion3D.on_dungeon_done_generating()
	for id in MultiplayerManager.players.keys():
		print_debug("spawning player " + str(id))
		_add_player_to_game(MultiplayerManager.players[id].id)

func _add_player_to_game(id: int):
	print_debug("Adding player with ID: " + str(id))
	if not _players_spawn_node:
		print_debug("ERROR: Could not find players spawn node")
		return
	var player_instance = multiplayer_scene.instantiate()
	print_debug("Player instance created")
	player_instance.name = str(id)
	player_instance.set_color(id)
	
	var spawn_position = Vector3(0, 0, 0)
	_players_spawn_node.add_child(player_instance, true)
	print_debug("Player added to scene tree")
	var spawn_points = get_tree().get_nodes_in_group("player_spawn_point")
	if spawn_points.size() > 0:
		spawn_position = spawn_points[0].global_transform.origin
		print("spawning at spawnpoint")
		print("spawn position", spawn_position)
	else:
		spawn_position = Vector3(37, 16, 0) # Fallback
		print("player spawn not found")
	
	# Wait for player to be fully set up
	await get_tree().create_timer(0.2).timeout
	
	# Add 4 scrap pieces to player's inventory
	#add_scrap_to_player(player_instance, 4)
	
	print_debug ("submitted name to ui for setup " + player_instance.name)
	if (not id == 1):
		ui.setup_player.rpc_id(id, player_instance.name)
	else:
		ui.setup_player(player_instance.name)
	
	for i in range(4):
		print("Check before spawn")
		MultiplayerRequest.request_item_spawn(Constants.ITEMS.SCRAP2, Transform3D().translated(Vector3(77, 77, 77)), id)
		print("item spawned for client with id ", id)
		print("spawned in scrap2 at generation...")
