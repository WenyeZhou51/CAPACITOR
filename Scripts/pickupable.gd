class_name Pickapable extends RigidBody3D

var drop_script
@export var Price: int
@export var type: String

func _ready() -> void:
	# Add to the scrap group for radar detection
	add_to_group("scrap")

func interact(player: Player) -> void:
	#if player.inv_size == 4:
		#var item_socket = player.get_node("Head/ItemSocket")
		#if item_socket.get_child_count() > 0:
			#var curr_item = item_socket.get_child(0)
			#curr_item.drop(player)

	var item_socket = player.get_node("Head/ItemSocket")
	var static_obj: StaticBody3D
	
	# Convert to static body first
	static_obj = convert_rigidbody_to_staticbody(self)
	
	# Remove from scrap group when in inventory
	if static_obj.is_in_group("scrap"):
		static_obj.remove_from_group("scrap")
	
	# Clear current item if exists
	if item_socket.get_child_count() > 0:
		var old_item = item_socket.get_child(0)
		print("Current inventory size is: " + str(player.inv_size))
		if player.inv_size == 4:
			print("currently swapping out "+ str(old_item))
			MultiplayerRequest.request_item_drop()
			player.inv_size = 4
		else:
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
	
	# Update tutorial flags if this is a coolant
	if type == "coolant":
		player.has_picked_up_coolant = true
		print("Set has_picked_up_coolant flag to true")
	
	# Update inventory
	if player.inv_size == 4:
		if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
			GameState.change_ui.emit(player.current_slot, static_obj.type, static_obj.Price)
		player.inventory[player.current_slot] = static_obj
	else:
		for i in range(player.inventory.size()):
			if player.inventory[i] == null:
				player.inventory[i] = static_obj
				player.inv_high.emit(player.current_slot, i, "name")
				player.current_slot = i
				player.inv_size += 1
				if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
					GameState.change_ui.emit(player.current_slot, static_obj.type, static_obj.Price)
				break
		player.is_holding = true

func convert_rigidbody_to_staticbody(rigidbody: RigidBody3D) -> StaticBody3D:
	drop_script = load("res://Scenes/prefabs/items/drop_item.gd")
	var flash_script = load("res://flash_light.gd")
	var spray_paint_script = load("res://spray_paint.gd")
	# Get the parent node
	var parent = rigidbody.get_parent()
	 # Create a new StaticBody3D
	var static_body = StaticBody3D.new()
	static_body.name = rigidbody.name  # Retain the same name for clarity
	
	print("Picked up a " + str(static_body.name))

	 # Transfer the transform (position, rotation, scale)
	static_body.transform = rigidbody.transform

	# Transfer children (collision shapes, meshes, etc.)
	for child in rigidbody.get_children():
		rigidbody.remove_child(child)  # Detach child from RigidBody3D
		static_body.add_child(child)  # Attach child to StaticBody3D
		child.owner = static_body  # Ensure the new owner is set for proper scene management
	
	static_body.collision_layer = 0
	static_body.collision_mask = 0
	if str(static_body.name) == "Flashlight":
		var flash_static = load("res://flash_light_static.gd")
		print("Adding flashlight static to object")
		static_body.set_script(flash_static)
		print("Load flashlight static to object successful")
		static_body.light_strength = rigidbody.light_strength
	elif str(static_body.name) == "SprayPaint":
		var spray_paint_static = load("res://spray_paint_static.gd")
		print("Adding spray paint static to object")
		static_body.set_script(spray_paint_static)
		print("Load spray paint static to object successful")
	else:
		print("Adding normal drop script")
		static_body.set_script(drop_script)
	static_body.Price = rigidbody.Price
	static_body.type = rigidbody.type
	
	# Don't add the static body to the scrap group
	# It's now in the player's inventory and shouldn't be shown on radar
	# We'll add it back when it's dropped
	
	var mesh_instance = static_body.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.visible = true
	# Optionally free the old RigidBody3D to clean up memory
	
	rigidbody.queue_free()
	
	return static_body
