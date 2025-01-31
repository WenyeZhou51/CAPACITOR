extends Node

@export var scrap_scenes: Array[PackedScene]
@export var num_scrap_to_spawn: int = 5
@export var door_scene: PackedScene



func spawn_scrap():
	# Get all scrap markers in the scene
	var scrap_markers = get_tree().get_nodes_in_group("scrap_marker")
	
	# If no markers or scenes, return
	if scrap_markers.size() == 0 or scrap_scenes.size() == 0:
		push_warning("No scrap markers found or no scrap scenes configured")
		return
		
	# Shuffle the markers array to randomize spawn positions
	scrap_markers.shuffle()
	
	# Spawn only up to the number of available markers
	var spawn_count = min(num_scrap_to_spawn, scrap_markers.size())
	
	# Spawn scrap at random markers
	for i in range(spawn_count):
		# Get random scrap scene
		var random_scrap_scene = scrap_scenes[randi() % scrap_scenes.size()]
		
		# Instance the scrap
		var scrap_instance = random_scrap_scene.instantiate()
		
		# Add it to the scene and set its position to the marker's position
		get_tree().root.add_child(scrap_instance)
		scrap_instance.global_position = scrap_markers[i].global_position

func spawn_doors():
	if not door_scene:
		push_warning("No door scene configured in GameManager")
		return
		
	var door_markers = get_tree().get_nodes_in_group("door_marker")
	
	if door_markers.size() == 0:
		push_warning("No door markers found in scene")
		return
		
	for marker in door_markers:
		var door_instance = door_scene.instantiate()
		get_tree().root.add_child(door_instance)
		# Use the full transform of the marker to preserve rotation
		door_instance.global_transform = marker.global_transform

func _on_navigation_region_3d_bake_finished() -> void:
	spawn_doors()
	spawn_scrap()
	
	

	
var is_ui_mode = false  # Tracks whether you're in UI interaction mode

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ALT:
			toggle_ui_mode()

	# Process mouse events in UI mode
	if is_ui_mode and event is InputEventMouseButton and event.pressed:
		# Let Godot handle button clicks as normal
		pass

func toggle_ui_mode():
	is_ui_mode = !is_ui_mode  # Toggle the mode

	if is_ui_mode:
		# Enable mouse for HUD interaction
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Lock mouse back to 3D gameplay
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
