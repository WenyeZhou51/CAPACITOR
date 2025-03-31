extends StaticBody3D

var pick_script
@export var Price: int = 0
@export var type: String
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func drop(player: CharacterBody3D, drop_position: Vector3 = Vector3.ZERO, drop_direction: Vector3 = Vector3.FORWARD) -> void:
	var item_socket = player.get_node("Head/ItemSocket")
	var world = get_tree().current_scene
	
	if self.get_parent() == item_socket:
		item_socket.remove_child(self)
		player._set_item_visibility(self, false, "before dropping")  # Hide before conversion
		
		var global_transform = player.global_transform
		self.global_transform.origin = global_transform.origin + (global_transform.basis.z * drop_direction * 2) + drop_position
		
		if self is StaticBody3D:
			var rigidbody = convert_staticbody_to_rigidbody(self, world)
			world.add_child(rigidbody)
			player._set_item_visibility(rigidbody, true, "dropped in world")
	
	# Clear from inventory
	for i in range(player.inventory.size()):
		if player.inventory[i] == self:
			player.inventory[i] = null
			player.inv_size -= 1
			if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
				GameState.change_ui.emit(i, "empty", 0)
			break
	player.is_holding = false
				
				
func convert_staticbody_to_rigidbody(static_body: StaticBody3D, world: Node3D) -> RigidBody3D:
	# Get the parent node
	
	var path = "res://Scenes/prefabs/items/" + str(static_body.type) + ".tscn"
	print("path is, ", path)
	var parent = static_body.get_parent()
	pick_script = load("res://Scripts/pickupable.gd")
	
	# Create a new RigidBody3D
	var scene = load(path)
	var rigidbody = scene.instantiate()
	rigidbody.name = static_body.name  # Retain the same name for clarity
	
	# Transfer the transform (position, rotation, scale)
	rigidbody.transform = static_body.transform
	
	# Transfer children (collision shapes, meshes, etc.)
	for child in static_body.get_children():
		static_body.remove_child(child)  # Detach child from StaticBody3D
		rigidbody.add_child(child)  # Attach child to RigidBody3D
		child.owner = rigidbody  # Ensure the new owner is set for proper scene management
	
	# Replace the StaticBody3D with the RigidBody3D in the scene tree
	#parent.remove_child(static_body)
	rigidbody.owner = parent  # Set the correct owner for saving in scenes
	
	
	# Restore collision layers and masks if necessary
	rigidbody.collision_layer = 1 << 2 # Example layer
	rigidbody.collision_mask = 0b00000101
	
	rigidbody.set_script(pick_script)
	rigidbody.Price = static_body.Price
	rigidbody.type = static_body.type
	
	var mesh_instance = static_body.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.visible = true
	
	var items_node = world.get_node("items")
	items_node.add_child(rigidbody)
	# Optionally free the old StaticBody3D to clean up memory
	static_body.queue_free()
	return rigidbody
