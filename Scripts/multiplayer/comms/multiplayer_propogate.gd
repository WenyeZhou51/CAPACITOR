extends Node

@rpc("authority", "call_local")
func propogate_team_score_update(val: int):
	GameState.set_team_score(val)
	GameState.check_game_end()
	
@rpc("authority", "call_local")
func propogate_item_interact(player_name: String, item_name: String):
		
	var item = get_tree().get_root().get_node_or_null("Level/items/" + item_name)
	var player = GameState.get_player_node_by_name(player_name)
	if player == null: return
	
	# Special cases for specific items
	if(item_name == "Cashier"):
		item = get_tree().get_root().get_node_or_null("Level/NavigationRegion3D/DungeonGenerator3D/start_room/Cashier")
	# Special case for the generator
	elif(item_name == "Generator" or item_name.begins_with("Generator")):
		item = get_tree().get_root().get_node_or_null("Level/Generator")
		if not item:
			# Fallback: look for generator in any group
			var generators = get_tree().get_nodes_in_group("generator")
			if generators.size() > 0:
				item = generators[0]

	print("interacting with", item)
	
	if (not item):
		print_debug("could not find item " + item_name)
		return
	item.interact(player)

@rpc("authority", "call_local")
func propogate_inventory_idx_change(player_id: int, new_slot: int):
	var player = GameState.get_player_node_by_name(str(player_id))
	if player == null: return
	if !player or player_id == MultiplayerManager.multiplayer.get_unique_id(): return
	player.set_inv_slot(new_slot)

@rpc("authority", "call_local")
func propogate_flash_toggle(player_name: String, item_name: String):
	var player = GameState.get_player_node_by_name(player_name)
	if player == null: return
	var item = player.get_node("Head/ItemSocket").get_child(0)
	var light = item.get_node("Model").get_node("FlashLight")
	light.visible = !light.visible

@rpc("authority", "call_local")
func propogate_item_drop(player_name: String):
	var player: Player = GameState.get_player_node_by_name(player_name)
	if player == null: return
	var item_socket = player.get_node("Head/ItemSocket")
	var curr_item = item_socket.get_child(0)
	if curr_item == null:
		return  # Early exit if there is no item to drop
	curr_item.drop(player)
	player.inventory[player.current_slot] = null
	if (str(player.get_tree().get_multiplayer().get_unique_id()) == player_name):
		GameState.change_ui.emit(player.current_slot, "empty")
	player.inv_size -= 1
	player.is_holding = false

@rpc("authority", "call_local")
func propogate_new_player_health(player_name: String, health: int):
	var player = GameState.get_player_node_by_name(player_name)
	if !player: return
	player.set_health(health)

############################## below prop non auth

@rpc("any_peer")
func propogate_player_play_sound(sound: Constants.SOUNDS):
	var caller_id = multiplayer.get_remote_sender_id();
	print_debug("SOUNDING", caller_id)
	var player = GameState.get_player_node_by_name(str(caller_id))
	if !player: return
	player.play_sound(sound)

@rpc("any_peer")
func propogate_player_stop_sound(sound: Constants.SOUNDS):
	var caller_id = multiplayer.get_remote_sender_id();
	var player = GameState.get_player_node_by_name(str(caller_id))
	if player == null: return
	player.stop_sound(sound)
