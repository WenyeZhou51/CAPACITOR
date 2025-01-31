extends Node

@export var scrap_scenes: Array[PackedScene]
@export var num_scrap_to_spawn: int = 5
@export var door_scene: PackedScene
@export var enemy_scene: PackedScene
@export var min_spawn_time: float = 15.0
@export var max_spawn_time: float = 30.0

var spawn_timer: Timer

func _ready():
	# Create and configure the spawn timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# Start the initial spawn timer
	_start_spawn_timer()

func _start_spawn_timer():
	var next_spawn_time = randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.start(next_spawn_time)

func spawn_enemy():
	if not enemy_scene:
		push_warning("No enemy scene configured in GameManager")
		return
		
	var enemy_markers = get_tree().get_nodes_in_group("enemy_marker")
	
	if enemy_markers.size() == 0:
		push_warning("No enemy markers found in scene")
		return
		
	# Pick a random marker
	var random_marker = enemy_markers[randi() % enemy_markers.size()]
	
	# Instance the enemy
	var enemy_instance = enemy_scene.instantiate()
	get_tree().root.add_child(enemy_instance)
	enemy_instance.global_position = random_marker.global_position

func _on_spawn_timer_timeout():
	spawn_enemy()
	_start_spawn_timer()  # Start the timer for the next spawn
	
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
	
