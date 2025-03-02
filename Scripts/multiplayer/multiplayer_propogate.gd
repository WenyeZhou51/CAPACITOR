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
func propagate_current_slot(player_id: int, new_slot: int):
	var player = get_tree().get_root().get_node("Level/players/" + str(player_id))
	if player:
		player.current_slot = new_slot

@rpc("authority", "call_local")
func changeHolding(player_name: String):
	var player = get_tree().get_root().get_node("Level/players/" + player_name)
	var item_socket = player.get_node("Head/ItemSocket")
	var old_item = null
	if(item_socket.get_child_count() > 0):
		old_item = item_socket.get_child(0)
	var new_item = player.inventory[player.current_slot]
	if old_item:
		if(old_item.type == "flashlight"):
			var light_node = old_item.get_node("Model/FlashLight")
			if light_node and light_node is Light3D:
				propogate_flash_toggle(player_name, old_item.name)
		item_socket.remove_child(old_item)
		var mesh_instance = old_item.get_node_or_null("MeshInstance3D")
		if mesh_instance:
			mesh_instance.visible = false
		var container = player.get_node("InventoryContainer")
		if container:
			container.add_child(old_item)  # Store the old item safely in the inventory container
		else:
			print("InventoryContainer not found. Old item may not be stored correctly.")
	if new_item:
		if new_item.get_parent():
			new_item.get_parent().remove_child(new_item)
		var mesh_instance = new_item.get_node_or_null("MeshInstance3D")
		if mesh_instance:
			mesh_instance.visible = true
		item_socket.add_child(new_item)
		if(new_item.type == "flashlight"):
			var light_node = new_item.get_node("Model/FlashLight")
			if light_node and light_node is Light3D:
				propogate_flash_toggle(player_name, new_item.name)
		new_item.transform = Transform3D()


@rpc("authority", "call_local")
func propogate_flash_toggle(player_name: String, item_name: String):
	var player = get_tree().get_root().get_node("Level/players/" + player_name)
	var item = player.get_node("Head/ItemSocket").get_child(0)
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


@rpc("authority", "call_local")
func propogate_player_dead(player_name: String):
	var player: Player = get_tree().get_root().get_node("Level/players/" + player_name)
	print_debug("PLAYER DEAD ", player_name, multiplayer.get_unique_id(), GameState.alive_count)
	if player.dead:
		return
	
	player.dead = true;
	player.death_effect()
	GameState.reduce_alive_count();
	GameState.check_game_end();
