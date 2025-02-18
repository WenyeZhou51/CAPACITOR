extends NavigationRegion3D

@export var bake_delay_frames: int = 5
@export var dungeon_generator_path: NodePath

var frame_counter: int = 0
var should_bake: bool = false

func on_dungeon_done_generating() -> void:
	print("[INFO] Dungeon generation completed. Starting bake countdown.")
	should_bake = true
	frame_counter = 0

func _process(delta: float) -> void:
	if not should_bake:
		return

	frame_counter += 1
	if frame_counter >= bake_delay_frames:
		print("[INFO] Baking NavMesh after delay.")
		bake_custom_navigation_mesh()
		should_bake = false

func bake_custom_navigation_mesh() -> void:
	var dungeon_generator = get_node(dungeon_generator_path)
	if dungeon_generator == null:
		push_warning("[WARNING] Dungeon generator node not found. Cannot bake navmesh.")
		return

	# Create a new navigation mesh resource
	var nav_mesh = NavigationMesh.new()
	
	# Configure the navigation mesh parameters
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.4
	nav_mesh.cell_size = 0.1
	nav_mesh.cell_height = 0.1
	nav_mesh.agent_max_climb = 0.1
	nav_mesh.agent_max_slope = 50
	nav_mesh.edge_max_error = 1.5
	
	# Assign it to this region
	navigation_mesh = nav_mesh
	
	# Force geometry update to include all CSG operations
	get_tree().call_group("csg", "make_meshes_collision_only", false)
	
	# Bake the navigation mesh
	bake_navigation_mesh(true)
	
	print("[INFO] NavMesh bake complete.")
