extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("cash")


func interact(player: CharacterBody3D):
	
	#if not get_tree().multiplayer.is_server():
		#return
	
	var item_socket = player.get_node("Head/ItemSocket")
	var value: int = 0
	
	if item_socket.get_child_count() > 0:
		var old_item = item_socket.get_child(0)
		print(old_item.name)
		value = old_item.Price
		item_socket.remove_child(old_item)
	
	player.inventory[player.current_slot] = null
	player.inv_size -= 1
	MultiplayerRequest.request_team_score_update(value)
	var msg: String
	if(value == 0):
		msg = "Please deposit a scrap"
		player.popup_instance.popup_text = msg
		player.popup_instance.pop_up()
	else:
		msg = "Scrap value " + str(value)
		player.popup_instance.popup_text = msg
		player.popup_instance.pop_up()
		GameState.change_ui.emit(player.current_slot, "empty")
		player.inv_size -= 1
		player.is_holding = false
