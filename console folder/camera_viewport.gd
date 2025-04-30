extends Control

var target_player: Node3D
var radar_size = Vector2(600, 300)
var ray_length = 50.0
var max_detection_distance = 100.0  # Maximum distance to detect walls

# Stores detected walls and enemies
var wall_hit_groups = []  # Array of arrays, each inner array contains hit points for one angle
var detected_enemies = []

# Debug variables
var ray_count = 0
var wall_hit_count = 0
var enemy_count = 0

# Maximum distance to show on radar
var max_radar_distance = 20.0

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
	wall_hit_groups.clear()
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
	
	# Perform raycasting in many directions
	var directions = 72
	var angle_step = 2 * PI / directions
	
	for i in range(directions):
		var angle = i * angle_step
		var direction = Vector3(cos(angle), 0, sin(angle))
		
		# Start position for ray
		var ray_start = player_pos + Vector3(0, 0.5, 0)  # Slightly above the floor
		
		# Create a hit group for this angle
		var hit_group = []
		
		# Cast multiple segments along the ray to detect multiple objects
		var max_segments = 5  # Maximum number of segments to check
		var segment_distance = 0.0
		var excluded_objects = []  # List of objects to exclude in subsequent raycasts
		
		for _segment in range(max_segments):
			query.from = ray_start + direction * segment_distance
			query.to = ray_start + direction * ray_length
			query.exclude = excluded_objects
			
			ray_count += 1
			
			var result = space_state.intersect_ray(query)
			if result:
				var hit_distance = player_pos.distance_to(result.position)
				
				# Only record hits within max detection distance
				if hit_distance <= max_detection_distance:
					wall_hit_count += 1
					hit_group.append({
						"position": result.position,
						"distance": hit_distance,
						"direction": direction,
						"normal": result.normal if result.has("normal") else Vector3.ZERO
					})
					
					# Add to excluded objects for next segment
					if result.collider and not excluded_objects.has(result.collider):
						excluded_objects.append(result.collider)
					
					# Update segment distance to continue a bit past the hit point
					segment_distance = hit_distance + 0.1  # Offset a bit to avoid hitting the same point
				else:
					# Hit is beyond our max distance, stop checking this ray
					break
				
				# If we've reached max ray length, stop checking
				if segment_distance >= ray_length:
					break
			else:
				# No more hits along this ray
				break
		
		# Add this group of hits to the wall_hit_groups
		wall_hit_groups.append(hit_group)
	
	# Check for all groups that might contain enemies
	var enemy_groups = ["enemies", "enemy", "venus"]
	
	for group_name in enemy_groups:
		if get_tree().has_group(group_name):
			# Detect enemies within range
			for node in get_tree().get_nodes_in_group(group_name):
				if abs(node.global_position.y - current_floor_y) < y_threshold:
					var distance = node.global_position.distance_to(player_pos)
					if distance <= max_detection_distance:
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
	
	# Draw all wall hits as connected lines
	for angle_idx in range(wall_hit_groups.size()):
		var hit_group = wall_hit_groups[angle_idx]
		
		# Process each hit in this group
		for hit_idx in range(hit_group.size()):
			var hit = hit_group[hit_idx]
			
			# Calculate normalized direction and distance
			var normalized_distance = min(hit.distance, max_radar_distance) / max_radar_distance
			
			# Calculate position using normalized direction and distance
			var direction_2d = Vector2(hit.direction.x, hit.direction.z).normalized()
			var point = center + direction_2d * normalized_distance * max_radius
			
			# Draw a small dot at each hit point
			draw_circle(point, 2, Color(0, 1, 0))
			
			# Connect to adjacent hits if they exist (both around the circle and for the same angle)
			
			# Connect to previous hit on same angle (inner walls)
			if hit_idx > 0:
				var prev_hit = hit_group[hit_idx - 1]
				var prev_norm_distance = min(prev_hit.distance, max_radar_distance) / max_radar_distance
				var prev_point = center + direction_2d * prev_norm_distance * max_radius
				draw_line(prev_point, point, Color(0, 1, 0), 1.5)
			
			# Connect to the hit at the same position in the adjacent angle (circular walls)
			var next_angle_idx = (angle_idx + 1) % wall_hit_groups.size()
			var next_hits = wall_hit_groups[next_angle_idx]
			
			# Only connect if the next angle has hits and this hit has a valid index
			if next_hits.size() > hit_idx:
				var next_hit = next_hits[hit_idx]
				
				# Calculate the adjacent point
				var next_direction_2d = Vector2(next_hit.direction.x, next_hit.direction.z).normalized()
				var next_norm_distance = min(next_hit.distance, max_radar_distance) / max_radar_distance
				var next_point = center + next_direction_2d * next_norm_distance * max_radius
				
				# Only connect if points are reasonably close
				var distance_between = point.distance_to(next_point)
				if distance_between < max_radius * 0.15:  # Arbitrary threshold
					draw_line(point, next_point, Color(0, 1, 0), 1.5)
	
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
	
