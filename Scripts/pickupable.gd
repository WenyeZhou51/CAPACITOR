class_name Pickapable extends RigidBody3D

var drop_script
@export var Price: int
@export var type: String

func interact(player: Player) -> void:
	if player.inv_size == 4:
		var item_socket = player.get_node("Head/ItemSocket")
		if item_socket.get_child_count() > 0:
			var curr_item = item_socket.get_child(0)
			curr_item.drop(player)

	var item_socket = player.get_node("Head/ItemSocket")
	var static_obj: StaticBody3D
	
	# Convert to static body first
	static_obj = convert_rigidbody_to_staticbody(self)
	
	# Clear current item if exists
	if item_socket.get_child_count() > 0:
		var old_item = item_socket.get_child(0)
		item_socket.remove_child(old_item)
		player._set_item_visibility(old_item, false, "replaced by new pickup")
		var container = player.get_node("InventoryContainer")
		if container:
			container.add_child(old_item)
	
	# Add new item
	if static_obj.get_parent():
		static_obj.get_parent().remove_child(static_obj)
	item_socket.add_child(static_obj)
	static_obj.transform = Transform3D()
	player._set_item_visibility(static_obj, true, "new pickup")
	
	# Update tutorial tracking for coolant pickup
	if static_obj.type == "coolant":
		player.has_picked_up_coolant = true
	
	# Update inventory
	if player.inv_size == 4:
		if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
			GameState.change_ui.emit(player.current_slot, static_obj.type)
		player.inventory[player.current_slot] = static_obj
	else:
		for i in range(player.inventory.size()):
			if player.inventory[i] == null:
				player.inventory[i] = static_obj
				player.inv_high.emit(player.current_slot, i, "name")
				player.current_slot = i
				player.inv_size += 1
				if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
					GameState.change_ui.emit(player.current_slot, static_obj.type)
				break
		player.is_holding = true

func convert_rigidbody_to_staticbody(rigidbody: RigidBody3D) -> StaticBody3D:
	drop_script = load("res://Scenes/prefabs/items/drop_item.gd")
	# Get the parent node
	var parent = rigidbody.get_parent()
	 # Create a new StaticBody3D
	var static_body = StaticBody3D.new()
	static_body.name = rigidbody.name  # Retain the same name for clarity
	
	 # Transfer the transform (position, rotation, scale)
	static_body.transform = rigidbody.transform

	# Transfer children (collision shapes, meshes, etc.)
	for child in rigidbody.get_children():
		rigidbody.remove_child(child)  # Detach child from RigidBody3D
		static_body.add_child(child)  # Attach child to StaticBody3D
		child.owner = static_body  # Ensure the new owner is set for proper scene management

	# Replace the RigidBody3D with the StaticBody3D in the scene tree
	parent.remove_child(rigidbody)
	parent.add_child(static_body)
	static_body.owner = parent.owner  # Set the correct owner for saving in scenes
	
	static_body.collision_layer = 0
	static_body.collision_mask = 0
	
	static_body.set_script(drop_script)
	static_body.Price = rigidbody.Price
	static_body.type = rigidbody.type
	var mesh_instance = static_body.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.visible = true
	# Optionally free the old RigidBody3D to clean up memory
	rigidbody.queue_free()
	
	return static_body
