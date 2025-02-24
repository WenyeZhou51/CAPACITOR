extends SubViewportContainer

var target_player: Node3D
var top_down_camera: Camera3D
var map_objects = {}  # Dictionary to track map objects

func _ready():
	# Set up viewport container properties
	custom_minimum_size = Vector2(300, 300)
	size = Vector2(300, 300)
	
	# Add green border
	add_theme_constant_override("margin_left", 2)
	add_theme_constant_override("margin_right", 2)
	add_theme_constant_override("margin_top", 2)
	add_theme_constant_override("margin_bottom", 2)
	
	# Set border color
	var style = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 1, 0, 1)  # Green border color
	add_theme_stylebox_override("panel", style)
	
	# Position the viewport in the desired location on the console screen
	anchor_left = 0.2
	anchor_top = 0.1
	anchor_right = 1.0
	anchor_bottom = 0.4
	
	# Make sure the viewport matches the container size
	$SubViewport.size = Vector2i(600, 300)
	
	# Initialize camera with proper settings
	top_down_camera = $SubViewport/Camera3D
	top_down_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	top_down_camera.size = 20.0
	# Make sure camera can see through everything
	top_down_camera.cull_mask = 0xFFFFFFFF  # See all visual layers
	
	# Set up viewport properties
	$SubViewport.transparent_bg = false
	$SubViewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	
	# Ensure viewport is ready for 3D rendering
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func set_target(player: Node3D):
	target_player = player
	
func is_visible_from_above(object_pos: Vector3, space_state: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D) -> bool:
	var ray_start = object_pos + Vector3(0, 20, 0)  # Start ray from above
	var ray_end = object_pos  # End at object position
	
	query.from = ray_start
	query.to = ray_end
	query.collision_mask = 0xFFFFFFFF  # Check against all collision layers
	query.exclude = []  # Don't exclude any objects
	
	var result = space_state.intersect_ray(query)
	# Simply return true for now to debug marker visibility
	return true

func _process(_delta):
	if not target_player or not is_instance_valid(target_player):
		queue_free()
		return
		
	print("Camera processing - Target player position: ", target_player.global_position)
	
	# Update camera position and rotation using basis vectors
	var target_pos = target_player.global_position
	top_down_camera.global_position = target_pos + Vector3(0, 15.0, 0)  # Changed from global_transform.origin
	top_down_camera.global_transform.basis = Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.BACK)
	
	# Clear old markers
	for obj in map_objects.values():
		if is_instance_valid(obj):
			obj.queue_free()
	map_objects.clear()
	
	# Add markers for nearby objects on the same floor
	var y_threshold = 2.0  # Vertical threshold to consider objects on the same floor
	var current_floor_y = target_player.global_position.y
	
	# Get all objects in the level
	var level_node = get_tree().get_root().get_node("Level")
	if not level_node:
		print("Level node not found!")
		return
		
	# Filter objects by floor level
	for node in get_tree().get_nodes_in_group("players"):
		if abs(node.global_position.y - current_floor_y) < y_threshold:
			print("Adding player marker at: ", node.global_position)
			add_marker(node, Color.GREEN)
	
	# Get physics world - with null check
	var world = $SubViewport.get_world_3d()
	if not world:
		print("World not found!")
		return
		
	var space_state = world.direct_space_state
	if not space_state:
		print("Space state not found!")
		return
		
	var query = PhysicsRayQueryParameters3D.new()
	
	# Check objects in groups with debug prints
	for group_name in ["players", "scrap", "coolant", "enemies", "doors"]:
		var nodes = get_tree().get_nodes_in_group(group_name)
		print("Found ", nodes.size(), " objects in group: ", group_name)
		
		for node in nodes:
			var object_pos = node.global_position
			print("Checking object in group ", group_name, " at position ", object_pos)
			
			# Simplified visibility check - just use Y threshold for now
			if abs(object_pos.y - current_floor_y) < y_threshold:
				var color = Color.WHITE
				match group_name:
					"players": color = Color.GREEN
					"scrap": color = Color.YELLOW
					"coolant": color = Color.BLUE
					"enemies": color = Color.RED
					"doors": color = Color.PURPLE
				print("Adding marker for ", group_name, " at position ", object_pos)
				add_marker(node, color)

func add_marker(node: Node3D, color: Color):
	var marker = CSGBox3D.new()
	marker.size = Vector3(1, 0.1, 1)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.8
	marker.material = material
	
	$SubViewport.add_child(marker)
	
	# Position marker in world space relative to camera
	marker.global_position = Vector3(
		node.global_position.x,
		0.1,  # Keep a consistent Y position for all markers
		node.global_position.z
	)
	map_objects[node] = marker 
