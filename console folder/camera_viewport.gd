extends Control

var target_player: Node3D
var radar_size = Vector2(600, 300)
var ray_length = 50.0
var radar_scale = 0.3 # Scale factor for better distribution across radar

# Stores detected walls and enemies
var wall_points = [] # Stores raycast hit points in order
var detected_enemies = []

# Debug variables
var ray_count = 0
var wall_hit_count = 0
var enemy_count = 0

# Maximum distance to show on radar
var max_radar_distance = 25.0

func _ready():
	# Configure the control node size
	custom_minimum_size = radar_size
	size = radar_size
	
	# Add green border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 1) # Dark gray background
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 1, 0, 1) # Green border color
	add_theme_stylebox_override("panel", style)
	
	print("[CAM DEBUG] Radar initialized with size: ", radar_size)

func set_target(player: Node3D):
	target_player = player
	print("[CAM DEBUG] Target set to player: ", player.name)

func _process(_delta):
	if not target_player or not is_instance_valid(target_player):
		print("[CAM DEBUG] Target player invalid or null - removing radar")
		queue_free()
		return
	
	# Clear previous detections
	wall_points.clear()
	detected_enemies.clear()
	
	# Reset debug counters
	ray_count = 0
	wall_hit_count = 0
	enemy_count = 0
	
	# Perform the radar scan
	perform_radar_scan()
	
	# Request redraw to update the radar
	queue_redraw()

func perform_radar_scan():
	if not target_player:
		return
		
	var player_pos = target_player.global_position
	var current_floor_y = player_pos.y
	var y_threshold = 2.0 # Objects within this range of player's Y are considered on same floor
	
	# Get physics space for raycasting
	var space_state = target_player.get_world_3d().direct_space_state
	if not space_state:
		print("[CAM DEBUG] ERROR: Could not get physics space state")
		return
	
	# Create raycast query parameters
	var query = PhysicsRayQueryParameters3D.new()
	
	# Try different collision masks if one isn't working
	query.collision_mask = 0xFFFFFFFF  # Try all collision layers
	
	# Perform raycasting in many directions (every 5 degrees)
	var directions = 72
	var angle_step = 2 * PI / directions
	
	# Pre-allocate array with correct size
	wall_points.resize(directions)
	
	for i in range(directions):
		var angle = i * angle_step
		var direction = Vector3(cos(angle), 0, sin(angle))
		
		query.from = player_pos + Vector3(0, 0.5, 0) # Slightly above the floor to avoid floor collisions
		query.to = query.from + direction * ray_length
		
		ray_count += 1
		
		var result = space_state.intersect_ray(query)
		if result:
			wall_hit_count += 1
			# Store point for this angle with distance info
			wall_points[i] = {
				"position": result.position,
				"distance": player_pos.distance_to(result.position),
				"direction": direction,
				"hit": true
			}
		else:
			# No hit - store a placeholder
			wall_points[i] = {
				"hit": false
			}
	
	# Check for all groups that might contain enemies
	var enemy_groups = ["enemies", "enemy", "venus"]
	
	for group_name in enemy_groups:
		if get_tree().has_group(group_name):
			# Detect enemies within range
			for node in get_tree().get_nodes_in_group(group_name):
				if abs(node.global_position.y - current_floor_y) < y_threshold:
					var distance = node.global_position.distance_to(player_pos)
					if distance <= ray_length:
						enemy_count += 1
						detected_enemies.append(node.global_position)

func _draw():
	if not target_player:
		return
	
	var center = size / 2
	var player_pos = target_player.global_position
	
	# Calculate the maximum radius in pixels
	var max_radius = min(center.x, center.y) * 0.95
	
	# Draw a faint grid
	draw_grid(center, max_radius)
	
	# Draw walls by connecting adjacent points
	if wall_hit_count > 0:
		var last_valid_point = null
		var last_valid_index = -1
		
		# Draw wall outline by connecting points
		for i in range(wall_points.size()):
			if wall_points[i].hit:
				var direction = wall_points[i].position - player_pos
				direction.y = 0 # Flatten to 2D plane
				
				# Calculate normalized direction and distance
				var distance = wall_points[i].distance
				var normalized_distance = min(distance, max_radar_distance) / max_radar_distance
				
				# Calculate position using normalized direction and distance
				var direction_2d = Vector2(direction.x, direction.z).normalized()
				var point = center + direction_2d * normalized_distance * max_radius
				
				# Connect to the previous valid point if possible
				if last_valid_point != null and (i - last_valid_index) < 3: # Only connect if they're not too far apart
					draw_line(last_valid_point, point, Color(0, 1, 0), 1.5)
				
				# Store this as the last valid point
				last_valid_point = point
				last_valid_index = i
		
		# Connect last and first points if close enough to complete the loop
		if last_valid_point != null:
			var first_valid_index = -1
			var first_valid_point = null
			
			# Find first valid point
			for i in range(wall_points.size()):
				if wall_points[i].hit:
					first_valid_index = i
					
					var direction = wall_points[i].position - player_pos
					direction.y = 0
					
					var distance = wall_points[i].distance
					var normalized_distance = min(distance, max_radar_distance) / max_radar_distance
					
					var direction_2d = Vector2(direction.x, direction.z).normalized()
					first_valid_point = center + direction_2d * normalized_distance * max_radius
					break
			
			# If the first and last points are close in the scan, connect them
			if first_valid_point != null and first_valid_index != -1:
				if (first_valid_index == 0 and last_valid_index == wall_points.size() - 1) or \
				   (wall_points.size() - last_valid_index + first_valid_index) < 3:
					draw_line(last_valid_point, first_valid_point, Color(0, 1, 0), 1.5)
	
	# Draw detected enemies (green dots)
	for enemy_pos in detected_enemies:
		var direction = enemy_pos - player_pos
		direction.y = 0 # Flatten to 2D plane
		
		# Calculate normalized direction and distance
		var distance = direction.length()
		var normalized_distance = min(distance, max_radar_distance) / max_radar_distance
		
		# Calculate position using normalized direction and distance
		var direction_2d = Vector2(direction.x, direction.z).normalized()
		var point = center + direction_2d * normalized_distance * max_radius
		
		# Draw green dot for enemy
		draw_circle(point, 5, Color(0, 1, 0))
	
	# Draw player position as a green X
	var x_size = 6
	draw_line(center - Vector2(x_size, x_size), center + Vector2(x_size, x_size), Color(0, 1, 0), 2)
	draw_line(center + Vector2(-x_size, x_size), center + Vector2(x_size, -x_size), Color(0, 1, 0), 2)
	
	# Draw debug text on radar 
	var debug_color = Color(0, 1, 0)
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), "Walls: " + str(wall_hit_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, debug_color)
	draw_string(ThemeDB.fallback_font, Vector2(10, 40), "Enemies: " + str(enemy_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, debug_color)

# Draw a circular grid for reference
func draw_grid(center: Vector2, max_radius: float):
	var grid_color = Color(0, 0.5, 0, 0.15)
	
	# Draw concentric circles
	for i in range(1, 4):
		var radius = max_radius * (i / 3.0)
		draw_arc(center, radius, 0, 2 * PI, 36, grid_color, 1.0)
	
	# Draw cardinal direction lines
	draw_line(center, center + Vector2(0, -max_radius), grid_color, 1.0)  # North
	draw_line(center, center + Vector2(max_radius, 0), grid_color, 1.0)   # East
	draw_line(center, center + Vector2(0, max_radius), grid_color, 1.0)   # South
	draw_line(center, center + Vector2(-max_radius, 0), grid_color, 1.0)  # West
	
