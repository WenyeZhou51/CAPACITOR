extends Node3D

var multiplayer_scene = preload("res://Scenes/player.tscn")
var _players_spawn_node: Node3D
var ui

func _ready() -> void:
	ui = $UI
	_players_spawn_node = get_tree().get_current_scene().get_node("players")
	GameState.alive_count = MultiplayerManager.player_count
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
	add_scrap_to_player(player_instance, 4)
	
	print_debug ("submitted name to ui for setup " + player_instance.name)
	if (not id == 1):
		ui.setup_player.rpc_id(id, player_instance.name)
	else:
		ui.setup_player(player_instance.name)

# Function to add scrap to a player's inventory
func add_scrap_to_player(player: CharacterBody3D, count: int) -> void:
	print("Adding scrap to player inventory: " + str(count) + " pieces")
	
	var scrap_scene = preload("res://Scenes/prefabs/items/scrap2.tscn")
	var items_node = get_tree().current_scene.get_node_or_null("items")
	
	if not items_node:
		items_node = Node3D.new()
		items_node.name = "items"
		get_tree().current_scene.add_child(items_node)
	
	for i in range(count):
		# Create scrap instance
		var scrap_instance = scrap_scene.instantiate()
		
		# Set price to 200 - accessing the property directly
		if "Price" in scrap_instance:
			scrap_instance.Price = 200
		
		# Also set the type to "scrap2" if it's not already set
		if "type" in scrap_instance and scrap_instance.type == "":
			scrap_instance.type = "scrap2"
		
		# Add to scene temporarily (needed for proper initialization)
		items_node.add_child(scrap_instance)
		
		# Position it in front of the player but not too close to avoid collision issues
		scrap_instance.global_position = player.global_position + player.global_transform.basis.z * -2 + Vector3(0, 1, 0)
		
		# Let the game handle adding item to inventory using existing mechanics
		if scrap_instance.has_method("interact"):
			# Make sure the player has room in inventory
			if player.inv_size < 4:
				scrap_instance.interact(player)
				print("Added scrap to player inventory slot " + str(player.inv_size - 1))
			else:
				print("Player inventory is full, couldn't add more scrap")
				scrap_instance.queue_free()
		else:
			print("ERROR: Scrap doesn't have interact method")
			scrap_instance.queue_free()
	
	# Make sure the first inventory slot is selected
	# This ensures the player has an item selected in their inventory
	player.set_inv_slot(0)
	
	
