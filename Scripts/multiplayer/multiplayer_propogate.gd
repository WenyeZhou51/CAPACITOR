extends Node

@rpc("authority", "call_local")
func propogate_team_score_update(val: int):
	GameState.set_team_score(val)
	GameState.check_game_end()
	
@rpc("authority", "call_local")
func propogate_item_interact(player_name: String, item_name: String):
		
	var item = get_tree().get_root().get_node("Level/items/" + item_name)
	var player = get_tree().get_root().get_node("Level/players/" + player_name)
	if(item_name == "planter_box_01_4k"):
		item = get_tree().get_root().get_node("Level/NavigationRegion3D/DungeonGenerator3D/start_room/StaticBody3D2/planter_box_01_4k")
	print("interacting with", item)
	
	if (not item):
		print_debug("could not find item " + item_name)
		return
	item.interact(player)

@rpc("authority", "call_local")
func propagate_current_slot_idx(player_id: int, new_slot: int):
	# Try multiple methods to find the player
	var player = null
	
	# Method 1: Use GameState
	player = GameState.get_player_node_by_name(str(player_id))
	
	# Method 2: Direct search in scene tree if GameState method failed
	if !player:
		player = get_tree().get_root().find_child(str(player_id), true, false)
	
	# Method 3: Search in players folder if both methods failed
	if !player:
		var level = get_tree().get_root().get_child(0)  # Assuming Level is the first child
		if level and level.has_node("players/" + str(player_id)):
			player = level.get_node("players/" + str(player_id))
	
	if !player:
		print("ERROR: Could not find player with ID: ", player_id)
		return
		
	# If we found the player, update their inventory slot
	if player is Player:
		player.set_inv_slot(new_slot)
	else:
		print("ERROR: Found node is not a Player: ", player)

@rpc("authority", "call_local")
func propogate_flash_toggle(player_name: String, item_name: String):
	# Get the player node
	var player = get_tree().get_root().get_node_or_null("Level/players/" + player_name)
	if not player:
		print("Error: Player not found: " + player_name)
		return
	
	# Get the item socket
	var item_socket = player.get_node_or_null("Head/ItemSocket")
	if not item_socket:
		print("Error: ItemSocket not found for player: " + player_name)
		return
	
	# Check if there's an item in the socket
	if item_socket.get_child_count() == 0:
		print("Error: No item in ItemSocket for player: " + player_name)
		return
	
	# Get the item and toggle the flashlight
	var item = item_socket.get_child(0)
	if not item:
		print("Error: Failed to get item from ItemSocket")
		return
	
	# Check if the item has the Model/FlashLight path
	var model = item.get_node_or_null("Model")
	if not model:
		print("Error: Item has no Model node: " + item.name)
		return
	
	var light = model.get_node_or_null("FlashLight")
	if not light:
		print("Error: Model has no FlashLight node: " + model.name)
		return
	
	# Toggle the light
	light.visible = !light.visible

@rpc("authority", "call_local")
func propogate_item_drop(player_name: String):
	var player = get_tree().get_root().find_child(player_name, true, false)
	if not player or not player is Player:
		print("ERROR: Could not find player with name: ", player_name)
		return
		
	var item_socket = player.get_node_or_null("Head/ItemSocket")
	if not item_socket:
		print("ERROR: ItemSocket not found for player: ", player_name)
		return
		
	var current_item = player.inventory[player.current_slot]
	if not current_item:
		print("WARNING: No item in current slot to drop")
		player.is_holding = false
		player.curSlotUpdating = false  # Reset in case it was stuck
		return
		
	# Get the item to drop
	var item = null
	if item_socket.get_child_count() > 0:
		item = item_socket.get_child(0)
	
	if not item:
		print("WARNING: No item in socket to drop")
		player.inventory[player.current_slot] = null
		player.is_holding = false
		player.curSlotUpdating = false  # Reset in case it was stuck
		return
	
	# Drop the item
	item.drop(player)
	player.inventory[player.current_slot] = null
	player.is_holding = false
	
	# Update UI
	if (str(player.get_tree().get_multiplayer().get_unique_id()) == player_name):
		GameState.change_ui.emit(player.current_slot, "empty")
	
	# Update inventory size
	player.inv_size -= 1
	
	# Safety reset
	player.curSlotUpdating = false

@rpc("authority", "call_local")
func propogate_new_player_health(player_name: String, health: int):
	var player = GameState.get_player_node_by_name(player_name)
	if !player: return
	player.set_health(health)
