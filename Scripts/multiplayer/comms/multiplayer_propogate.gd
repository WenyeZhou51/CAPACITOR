extends Node

@rpc("authority", "call_local")
func propogate_team_score_update(val: int):
	GameState.set_team_score(val)
	GameState.check_game_end()
	
@rpc("authority", "call_local")
func propogate_item_interact(player_name: String, item_name: String):
		
	var item = get_tree().get_root().get_node("Level/items/" + item_name)
	var player = GameState.get_player_node_by_name(player_name)
	if(item_name == "planter_box_01_4k"):
		item = get_tree().get_root().get_node("Level/NavigationRegion3D/DungeonGenerator3D/start_room/StaticBody3D2/planter_box_01_4k")
	print("interacting with", item)
	
	if (not item):
		print_debug("could not find item " + item_name)
		return
	item.interact(player)

@rpc("authority", "call_local")
func propogate_inventory_idx_change(player_id: int, new_slot: int):
	var player = GameState.get_player_node_by_name(str(player_id))
	if !player or player_id == MultiplayerManager.multiplayer.get_unique_id(): return
	player.set_inv_slot(new_slot)

@rpc("authority", "call_local")
func propogate_flash_toggle(player_name: String, item_name: String):
	var player = GameState.get_player_node_by_name(player_name)
	var item = player.get_node("Head/ItemSocket").get_child(0)
	var light = item.get_node("Model").get_node("FlashLight")
	light.visible = !light.visible

@rpc("authority", "call_local")
func propogate_item_drop(player_name: String):
	var player: Player = GameState.get_player_node_by_name(player_name)
	var item_socket = player.get_node("Head/ItemSocket")
	var curr_item = item_socket.get_child(0)
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
	player.stop_sound(sound)
