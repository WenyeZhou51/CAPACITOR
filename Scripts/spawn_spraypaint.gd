extends Node

# This script is used to spawn a spraypaint item in the game

func _ready():
	# Wait a short time before spawning to ensure the level is fully loaded
	await get_tree().create_timer(0.5).timeout
	spawn_spraypaint()

func spawn_spraypaint():
	# Load the spraypaint scene
	var spraypaint_scene = load("res://Scenes/prefabs/items/spraypaint.tscn")
	if spraypaint_scene:
		# Create an instance of the spraypaint
		var spraypaint = spraypaint_scene.instantiate()
		
		# Set a random position near the player or at a specific location
		var level = get_tree().current_scene
		var items_container = level.get_node_or_null("items")
		
		if items_container:
			items_container.add_child(spraypaint)
			
			# Position near player start position with slight offset
			var player_container = level.get_node_or_null("players")
			if player_container and player_container.get_child_count() > 0:
				var player = player_container.get_child(0)
				spraypaint.global_transform.origin = player.global_transform.origin + Vector3(1.0, 0.5, 1.0)
			else:
				# Fallback position if player not found
				spraypaint.global_transform.origin = Vector3(0, 1, 0)
		else:
			# If items container not found, add directly to the scene
			level.add_child(spraypaint)
			spraypaint.global_transform.origin = Vector3(0, 1, 0)
		
		# Set properties
		spraypaint.Price = 50  # Set a price for the item
		print("Spawned spraypaint at position:", spraypaint.global_transform.origin)
	else:
		push_error("Failed to load spraypaint scene") 