extends StaticBody3D

var pick_script
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func drop(player: CharacterBody3D, drop_position: Vector3 = Vector3.ZERO, drop_direction: Vector3 = Vector3.FORWARD) -> void:
	# 1) Get the reference to the player's 'ItemSocket'
	var item_socket = player.get_node("Head/ItemSocket") # Adjust path as needed

	# 2) Re-parent this object back to the world or a specific drop parent
	if self.get_parent() == item_socket:
		
		var world = get_tree().current_scene # You can adjust this to a specific node if needed
		item_socket.remove_child(self)
		world.add_child(self)
		
		# 3) Set the drop position relative to the player or item socket
		# For example, position it in front of the player
		var global_transform = player.global_transform
		self.global_transform.origin = global_transform.origin + (global_transform.basis.z * drop_direction * 2) + drop_position
		
		# 4) Enable physics behavior by converting back to RigidBody3D
		if self is StaticBody3D:
			convert_staticbody_to_rigidbody(self)

func convert_staticbody_to_rigidbody(static_body: StaticBody3D):
	# Get the parent node
	var parent = static_body.get_parent()
	
	pick_script = load("res://Scenes/prefabs/items/flash.gd")
	
	# Create a new RigidBody3D
	var rigidbody = RigidBody3D.new()
	rigidbody.name = static_body.name  # Retain the same name for clarity
	
	# Transfer the transform (position, rotation, scale)
	rigidbody.transform = static_body.transform
	
	# Transfer children (collision shapes, meshes, etc.)
	for child in static_body.get_children():
		static_body.remove_child(child)  # Detach child from StaticBody3D
		rigidbody.add_child(child)  # Attach child to RigidBody3D
		child.owner = rigidbody  # Ensure the new owner is set for proper scene management
	
	# Replace the StaticBody3D with the RigidBody3D in the scene tree
	parent.remove_child(static_body)
	parent.add_child(rigidbody)
	rigidbody.owner = parent.owner  # Set the correct owner for saving in scenes
	
	
	# Restore collision layers and masks if necessary
	rigidbody.collision_layer = 1 << 2 # Example layer
	rigidbody.collision_mask = 0b00000101
	
	rigidbody.set_script(pick_script)

	# Optionally free the old StaticBody3D to clean up memory
	static_body.queue_free()
