extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("cash")


func interact(player: CharacterBody3D) -> int:
	var item_socket = player.get_node("Head/ItemSocket")
	var value: int = 0
	if item_socket.get_child_count() > 0:
		var old_item = item_socket.get_child(0)
		print(old_item.name)
		value = old_item.Price
		item_socket.remove_child(old_item)
	return value
