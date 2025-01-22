extends Node3D

@export var door_scene: PackedScene
var nav_region: NavigationRegion3D
var door_instance: Node3D = null  # Track if we've already spawned a door

func _ready() -> void:
	print("[DoorMarker] Initializing at position: ", global_position)
	# Find the NavigationRegion3D node
	nav_region = get_tree().get_first_node_in_group("nav_region")
	if nav_region:
		print("[DoorMarker] Connected to NavigationRegion3D")
		nav_region.nav_mesh_bake_complete.connect(_on_nav_mesh_bake_complete)
	else:
		push_warning("[DoorMarker] NavigationRegion3D not found for door marker.")

func _on_nav_mesh_bake_complete() -> void:
	print("signal received")
	if door_instance:
		print("[DoorMarker] Door already spawned, ignoring signal")
		return
		
	if door_scene:
		print("[DoorMarker] Attempting to spawn door")
		door_instance = door_scene.instantiate()
		add_child(door_instance)
		door_instance.global_transform = global_transform
		print("[DoorMarker] Door spawned successfully at: ", global_position)
	else:
		push_warning("[DoorMarker] No door scene assigned to door marker")
