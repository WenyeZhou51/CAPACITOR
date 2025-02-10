extends Node3D

var multiplayer_scene = preload("res://Scenes/player.tscn")
var _players_spawn_node: Node3D
var ui

func _ready() -> void:
	ui = $UI
	_players_spawn_node = get_tree().get_current_scene().get_node("players")
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
	
	var spawn_position = Vector3(40, 45, 0)
	_players_spawn_node.add_child(player_instance, true)
	print_debug("Player added to scene tree")
	player_instance.global_position = Vector3(40, 45, 0)
	
	print_debug ("submitted name to ui for setup " + player_instance.name)
	if (not id == 1):
		ui.setup_player.rpc_id(id, player_instance.name)
	else:
		ui.setup_player(player_instance.name)
	
	
