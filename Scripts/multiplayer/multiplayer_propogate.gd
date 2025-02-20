extends Node

@rpc("authority", "call_local")
func propogate_team_score_update(val: int):
	GameState.set_team_score(val)
	GameState.check_game_end()
	
@rpc("authority", "call_local")
func propogate_item_interact(player_name: String, item_name: String):
<<<<<<< HEAD
	var item = get_tree().get_root().get_node("Level/items/" + item_name)
	var player = get_tree().get_root().get_node("Level/players/" + player_name)
=======
		
	var item = get_tree().get_root().get_node("Level/items/" + item_name)
	var player = get_tree().get_root().get_node("Level/players/" + player_name)
	if(item_name == "planter_box_01_4k"):
		item = get_tree().get_root().get_node("Level/NavigationRegion3D/DungeonGenerator3D/start_room/StaticBody3D2/planter_box_01_4k")
	print("interacting with", item)
>>>>>>> master
	
	if (not item):
		print_debug("could not find item " + item_name)
		return
	item.interact(player)

@rpc("authority", "call_local")
func propogate_flash_toggle(item_name: String):
	var item = get_tree().get_current_scene().find_child(item_name, true)
	var light = item.get_node("Model").get_node("FlashLight")
	light.visible = !light.visible

@rpc("authority", "call_local")
func propogate_item_drop(player_name: String):
	var player: Player = get_tree().get_root().get_node("Level/players/" + player_name)
	var item_socket = player.get_node("Head/ItemSocket")
	var curr_item = item_socket.get_child(0)
	curr_item.drop(player)
	player.inventory[player.current_slot] = null
	if (str(player.get_tree().get_multiplayer().get_unique_id()) == player_name):
		GameState.change_ui.emit(player.current_slot, "empty")
	player.inv_size -= 1
	player.is_holding = false
