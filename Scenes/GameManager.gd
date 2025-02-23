extends Node

@export var scrap_scenes: Array[PackedScene]
@export var coolant_scene: PackedScene
@export var num_scrap_to_spawn: int = 5
@export var num_coolant_to_spawn: int = 9
@export var door_scene: PackedScene
@export var enemy_scenes: Array[PackedScene]
@export var min_spawn_time: float = 1 # 15.0
@export var max_spawn_time: float = 1 # 30.0
@export var max_enemies: int = 10  # Maximum allowed simultaneous enemies
var current_enemies: int = 0       # Track current enemy count
"num_scrap_to_spawn"
var items_node
var spawn_timer: Timer

func _ready():
	items_node = get_tree().get_current_scene().get_node("items")
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
	if current_enemies >= max_enemies:
		return  # Don't spawn if we're at capacity
		
	if not enemy_scenes:
		push_warning("No enemy scenes configured in GameManager")
		return
		
	var enemy_markers = get_tree().get_nodes_in_group("enemy_marker")
	
	if enemy_markers.size() == 0:
		push_warning("No enemy markers found in scene")
		return
		
	# Pick a random marker
	var random_marker = enemy_markers[randi() % enemy_markers.size()]
	
	# Instance a random enemy from enemy list
	var enemy_instance = enemy_scenes[randi() % enemy_scenes.size()].instantiate()
	items_node.add_child(enemy_instance, true)
	enemy_instance.global_position = random_marker.global_position
	current_enemies += 1
	print("enemy spawned (", current_enemies, "/", max_enemies, ")")
	
	# Connect to enemy's destruction signal
	enemy_instance.tree_exited.connect(_on_enemy_destroyed.bind())

func _on_enemy_destroyed():
	current_enemies = max(0, current_enemies - 1)
	print("enemy destroyed (", current_enemies, "/", max_enemies, ")")
func _on_spawn_timer_timeout():
	if not multiplayer.is_server(): return
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
		items_node.add_child(scrap_instance, true)
		scrap_instance.global_position = scrap_markers[i].global_position



func spawn_coolant():
	# Get all scrap markers in the scene
	var coolant_scene = preload("res://Scenes/prefabs/items/coolant.tscn")
	var coolant_markers = get_tree().get_nodes_in_group("coolant_marker")
	
	# If no markers or scenes, return
	if coolant_markers.size() == 0:
		push_warning("No coolant markers found or no scrap scenes configured")
		return
		
	# Shuffle the markers array to randomize spawn positions
	coolant_markers.shuffle()
	
	# Spawn only up to the number of available markers
	var spawn_count = min(num_coolant_to_spawn, coolant_markers.size())
	print(spawn_count)
	# Spawn scrap at random markers
	for i in range(spawn_count):
		
		# Instance the scrap
		var coolant_instance = coolant_scene.instantiate()
		
		# Add it to the scene and set its position to the marker's position
		items_node.add_child(coolant_instance, true)
		coolant_instance.global_position = coolant_markers[i].global_position



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
		items_node.add_child(door_instance, true)
		# Use the full transform of the marker to preserve rotation
		door_instance.global_transform = marker.global_transform

func _on_navigation_region_3d_bake_finished() -> void:
	if not multiplayer.is_server(): return
	print_debug("spawning scraps doors and coolant as server " + str(multiplayer.get_unique_id()))
	spawn_doors()
	spawn_scrap()
	spawn_coolant()
	
	
