extends Control

var target_player: Node3D
var radar_size = Vector2(600, 300)
var ray_length = 100.0
var max_detection_distance = 100.0  # Maximum distance to detect walls

# Stores detected walls and enemies
var wall_hit_groups = []  # Array of arrays, each inner array contains hit points for one angle
var detected_enemies = []
var detected_scraps = []  # New array to track detected scraps
var all_wall_points = []  # Flattened array of all wall points for nearest neighbor calculations

# Debug variables
var ray_count = 0
var wall_hit_count = 0
var enemy_count = 0
var scrap_count = 0  # New counter for scraps

# Maximum distance to show on radar
var max_radar_distance = 100.0

# Connection parameters
var max_connection_distance = 3.0  # Maximum 3D distance to connect points

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
	detected_scraps.clear()  # Clear scraps
	all_wall_points.clear()
	
	# Reset debug counters
	ray_count = 0
	wall_hit_count = 0
	enemy_count = 0
	scrap_count = 0  # Reset scrap counter
	
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
		var max_segments = 10  # Increased to detect more objects along ray
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
					# Check if the hit object is an enemy or scrap
					if result.collider:
						if result.collider.is_in_group("enemy"):
							enemy_count += 1
							detected_enemies.append(result.position)
						elif result.collider.is_in_group("scrap"):
							scrap_count += 1
							detected_scraps.append(result.position)
						else:
							# It's a wall or other object
							wall_hit_count += 1
							var hit_point = {
								"position": result.position,
								"distance": hit_distance,
								"direction": direction,
								"normal": result.normal if result.has("normal") else Vector3.ZERO,
								"display_pos": Vector2.ZERO,  # Will be filled during drawing
								"connected": false  # Track if this point has been connected
							}
							
							hit_group.append(hit_point)
							all_wall_points.append(hit_point)
					
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
	
	# Also scan for any enemies or scraps that might be missed by raycasting
	check_groups_in_range(player_pos, current_floor_y, y_threshold)

# Check for enemies and scraps using the group system
func check_groups_in_range(player_pos: Vector3, current_floor_y: float, y_threshold: float):
	# Check for enemies
	if get_tree().has_group("enemy"):
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is Node3D:
				if abs(enemy.global_position.y - current_floor_y) < y_threshold:
					var distance = enemy.global_position.distance_to(player_pos)
					if distance <= max_detection_distance:
						# Only count if not already detected by raycast
						var already_detected = false
						for pos in detected_enemies:
							if pos.distance_to(enemy.global_position) < 0.5:  # Close enough to be the same
								already_detected = true
								break
						if not already_detected:
							enemy_count += 1
							detected_enemies.append(enemy.global_position)
	
	# Check for venus enemies specifically
	if get_tree().has_group("venus"):
		for venus in get_tree().get_nodes_in_group("venus"):
			if venus is Node3D:
				if abs(venus.global_position.y - current_floor_y) < y_threshold:
					var distance = venus.global_position.distance_to(player_pos)
					if distance <= max_detection_distance:
						# Only count if not already detected by raycast
						var already_detected = false
						for pos in detected_enemies:
							if pos.distance_to(venus.global_position) < 0.5:  # Close enough to be the same
								already_detected = true
								break
						if not already_detected:
							enemy_count += 1
							detected_enemies.append(venus.global_position)
	
	# Check for earworm enemies specifically
	if get_tree().has_group("earworm"):
		for earworm in get_tree().get_nodes_in_group("earworm"):
			if earworm is Node3D:
				if abs(earworm.global_position.y - current_floor_y) < y_threshold:
					var distance = earworm.global_position.distance_to(player_pos)
					if distance <= max_detection_distance:
						# Only count if not already detected by raycast
						var already_detected = false
						for pos in detected_enemies:
							if pos.distance_to(earworm.global_position) < 0.5:  # Close enough to be the same
								already_detected = true
								break
						if not already_detected:
							enemy_count += 1
							detected_enemies.append(earworm.global_position)
	
	# Check for scraps
	if get_tree().has_group("scrap"):
		for scrap in get_tree().get_nodes_in_group("scrap"):
			if scrap is Node3D:
				if abs(scrap.global_position.y - current_floor_y) < y_threshold:
					var distance = scrap.global_position.distance_to(player_pos)
					if distance <= max_detection_distance:
						# Only count if not already detected by raycast
						var already_detected = false
						for pos in detected_scraps:
							if pos.distance_to(scrap.global_position) < 0.5:  # Close enough to be the same
								already_detected = true
								break
						if not already_detected:
							scrap_count += 1
							detected_scraps.append(scrap.global_position)

func _draw():
	if not target_player:
		return
	
	var center = size / 2
	var player_pos = target_player.global_position
	
	# Calculate the maximum radius in pixels
	var max_radius = min(center.x, center.y) * 0.95
	
	# Draw a faint grid
	draw_grid(center, max_radius)
	
	# First pass: calculate display positions for all points
	for point in all_wall_points:
		# Calculate normalized direction and distance
		var normalized_distance = min(point.distance, max_radar_distance) / max_radar_distance
		
		# Calculate position using normalized direction and distance
		var direction_2d = Vector2(point.direction.x, point.direction.z).normalized()
		point.display_pos = center + direction_2d * normalized_distance * max_radius
		
		# Draw a small dot at each hit point
		draw_circle(point.display_pos, 2, Color(0, 1, 0))
	
	# Second pass: connect points based on nearest neighbors
	for point in all_wall_points:
		# Find the nearest unconnected points
		var nearest_points = find_nearest_points(point, all_wall_points, max_connection_distance)
		
		# Connect to the nearest points
		for nearest in nearest_points:
			# Draw line between points
			draw_line(point.display_pos, nearest.display_pos, Color(0, 1, 0), 1.5)
	
	# Draw detected enemies (red dots)
	for enemy_pos in detected_enemies:
		var direction = enemy_pos - player_pos
		direction.y = 0 # Flatten to 2D plane
		
		# Calculate normalized direction and distance
		var distance = direction.length()
		var normalized_distance = min(distance, max_radar_distance) / max_radar_distance
		
		# Calculate position using normalized direction and distance
		var direction_2d = Vector2(direction.x, direction.z).normalized()
		var point = center + direction_2d * normalized_distance * max_radius
		
		# Draw red dot for enemy
		draw_circle(point, 5, Color(1, 0, 0))
	
	# Draw detected scraps (yellow dots)
	for scrap_pos in detected_scraps:
		var direction = scrap_pos - player_pos
		direction.y = 0 # Flatten to 2D plane
		
		# Calculate normalized direction and distance
		var distance = direction.length()
		var normalized_distance = min(distance, max_radar_distance) / max_radar_distance
		
		# Calculate position using normalized direction and distance
		var direction_2d = Vector2(direction.x, direction.z).normalized()
		var point = center + direction_2d * normalized_distance * max_radius
		
		# Draw yellow dot for scrap
		draw_circle(point, 5, Color(1, 1, 0))
	
	# Draw player position as a green X
	var x_size = 6
	draw_line(center - Vector2(x_size, x_size), center + Vector2(x_size, x_size), Color(0, 1, 0), 2)
	draw_line(center + Vector2(-x_size, x_size), center + Vector2(x_size, -x_size), Color(0, 1, 0), 2)
	
	# Draw debug text on radar 
	var debug_color = Color(0, 1, 0)
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), "Walls: " + str(wall_hit_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, debug_color)
	draw_string(ThemeDB.fallback_font, Vector2(10, 40), "Enemies: " + str(enemy_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, debug_color)
	draw_string(ThemeDB.fallback_font, Vector2(10, 60), "Scraps: " + str(scrap_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, debug_color)

# Find the nearest neighboring points to the given point
func find_nearest_points(point, all_points, max_distance):
	var nearest = []
	
	for other in all_points:
		# Skip self
		if other == point:
			continue
			
		# Calculate 3D distance between points
		var distance = point.position.distance_to(other.position)
		
		# Only consider points within max connection distance
		if distance <= max_distance:
			nearest.append(other)
	
	# Sort by distance (if needed)
	nearest.sort_custom(func(a, b): return point.position.distance_to(a.position) < point.position.distance_to(b.position))
	
	# Limit to 2 nearest neighbors to avoid over-connecting
	return nearest.slice(0, min(2, nearest.size()))

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
	
