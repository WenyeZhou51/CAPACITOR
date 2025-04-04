extends Node

@rpc("any_peer", "call_local")
func confirm_team_score_update(val: int):
	var new_score = GameState.get_team_score() + val;
	MultiplayerPropogate.propogate_team_score_update.rpc(new_score)

@rpc("any_peer", "call_local")
func confirm_item_interact(item_name: String, id: int):
	var player_name: String
	if(id == -1):
		player_name = str(multiplayer.get_remote_sender_id());
		print("no id feeded in")
	else:
		player_name = str(id)
	MultiplayerPropogate.propogate_item_interact.rpc(player_name, item_name)
	
@rpc("any_peer", "call_local")
func confirm_flash_toggle(item_name: String):
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_flash_toggle.rpc(player_name, item_name)
	
@rpc("any_peer", "call_local")
func confirm_current_slot(new_slot: int):
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_tree().get_root().get_node("Level/players/" + str(sender_id))
	if player:
		player.current_slot = new_slot
		MultiplayerPropogate.propagate_current_slot.rpc(sender_id, new_slot)

@rpc("any_peer", "call_local")
func confirm_item_drop():
	var player_name = str(multiplayer.get_remote_sender_id());
	MultiplayerPropogate.propogate_item_drop.rpc(player_name)

@rpc("any_peer", "call_local")
func confirm_inventory_idx_change(idx: int):
	var sender_id = multiplayer.get_remote_sender_id()
	MultiplayerPropogate.propogate_inventory_idx_change.rpc(sender_id, idx)

@rpc("any_peer", "call_local")
func confirm_item_spawn(item: Constants.ITEMS, position: Transform3D, id = -1):
	var item_node = get_tree().current_scene.get_node("items")
	
	var scene
	var instance
	match item:
		Constants.ITEMS.FLASHLIGHT:
			scene = preload("res://Scenes/prefabs/items/flashlight.tscn")
			instance = scene.instantiate()
			instance.global_transform = position
		Constants.ITEMS.COOLANT:
			scene = preload("res://Scenes/prefabs/items/coolant.tscn")
			instance = scene.instantiate()
			instance.global_transform = position
		Constants.ITEMS.SCRAP2:
			scene = preload("res://Scenes/prefabs/items/scrap2.tscn")
			instance = scene.instantiate()
			instance.global_transform = position
	item_node.add_child(instance, true)
	
	if(id != -1):
		MultiplayerRequest.request_item_interact(instance.name, id)
