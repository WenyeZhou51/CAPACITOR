extends RigidBody3D


var drop_script
@export var Price: int

func interact(player: CharacterBody3D) -> StaticBody3D:
#	 1) Get the reference to the player's 'ItemSocket'
	var item_socket = player.get_node("Head/ItemSocket") # Adjust path as needed
	var static_obj: StaticBody3D
	
	if item_socket.get_child_count() > 0:
		var old_item = item_socket.get_child(0)
		item_socket.remove_child(old_item)
		var container = player.get_node("InventoryContainer")
		if container:
			container.add_child(old_item)
		else:
			print("no container")
	
	# 2) Re-parent this object to the player's ItemSocket
	if self.get_parent():
		self.get_parent().remove_child(self)
	item_socket.add_child(self)
	
	# 4) (Optional) Reset transform so the object lines up exactly with the socket
	self.transform = Transform3D()
	
	# 5) Disable physics behavior (e.g., gravity, rigid body movement)
	return convert_rigidbody_to_staticbody(self)

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
	# Optionally free the old RigidBody3D to clean up memory
	rigidbody.queue_free()
	
	return static_body
