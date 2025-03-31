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
	print("Attempting to load: ", path)
	var parent = static_body.get_parent()
	pick_script = load("res://Scripts/pickupable.gd")
	
	# Create a new RigidBody3D
	var scene = load(path)
	if scene == null:
		push_error("Failed to load scene: " + path)
		print("ERROR: Cannot drop item - scene file not found: " + path)
		
		# Create a simple RigidBody3D as fallback
		var fallback_rigidbody = RigidBody3D.new()
		fallback_rigidbody.name = static_body.name
		fallback_rigidbody.transform = static_body.transform
		fallback_rigidbody.collision_layer = 1 << 2
		fallback_rigidbody.collision_mask = 0b00000101
		fallback_rigidbody.set_script(pick_script)
		fallback_rigidbody.Price = static_body.Price
		fallback_rigidbody.type = static_body.type
		
		# Copy children
		for child in static_body.get_children():
			static_body.remove_child(child)
			fallback_rigidbody.add_child(child)
			child.owner = fallback_rigidbody
		
		# Add to items container
		var items_node = world.get_node("items")
		if items_node:
			items_node.add_child(fallback_rigidbody)
		else:
			world.add_child(fallback_rigidbody)
		
		static_body.queue_free()
		return fallback_rigidbody
	
	var rigidbody = scene.instantiate()
	rigidbody.name = static_body.name  # Retain the same name for clarity
	
	# Transfer the transform (position, rotation, scale)
	rigidbody.transform = static_body.transform
	
	# Only transfer specific children to avoid duplicating what's already in the scene
	var children_to_keep = []
	for child in static_body.get_children():
		if child is MeshInstance3D or child is Light3D:
			static_body.remove_child(child)
			children_to_keep.append(child)
	
	# Add the items node properly
	var items_node = world.get_node_or_null("items")
	if items_node:
		items_node.add_child(rigidbody)
	else:
		# Fallback - add directly to world
		world.add_child(rigidbody)
	
	# Restore collision layers and masks if necessary
	rigidbody.collision_layer = 1 << 2 # Bit 3 (layer 4)
	rigidbody.collision_mask = 0b00000101 # Bits 1 and 3 (layers 1 and 3)
	
	# Set properties
	rigidbody.Price = static_body.Price
	rigidbody.type = static_body.type
	
	# Apply impulse to make it feel more natural
	if rigidbody is RigidBody3D:
		rigidbody.apply_impulse(Vector3(0, 2, -5))
		
	# Clean up the static body
	static_body.queue_free()
	
	print("Successfully dropped item as: " + rigidbody.name)
	return rigidbody
