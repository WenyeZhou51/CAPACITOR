extends CharacterBody3D

# Existing exports
@export var gravity: float = 9.8
@export var chase_speed: float = 6.0 # originally 6. 0 for dbg
@export var turn_speed: float = 2.0
@export var attack_radius: float = 3.0 # originally 3
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var debug_visual_colors: bool = true  # Temporarily enabled for debugging
@export var animation_speed: float = 8.0
@export var chase_animation_speed: float = 16.0
@export var detection_area: Area3D
@export var detection_range: float = 15.0  # How far the enemy can detect the player

# New exports for viewcone avoidance
@export var view_range: float = 10.0
@export var view_angle: float = 90.0

# State variables
var player: Player
var animation_player: AnimationPlayer
var agent: NavigationAgent3D
var local_velocity: Vector3 = Vector3.ZERO
var is_walking: bool = false
var nav_ready: bool = false
var has_seen_player: bool = false
var is_active: bool = true
var path_update_cooldown = 0.2  # Reduced for more responsive avoidance
var path_update_timer = 0.0
var los_cooldown = 0.5
var los_timer = 0.0
var los
var stuck_timer: float = 0.0
var stuck_threshold: float = 5.0

func _ready() -> void:
	randomize()
	
	# Add to the enemy group for radar detection
	add_to_group("enemy")
	add_to_group("raBIT")  # Updated to match enemy type
	
	floor_snap_length = 1.0
	
	animation_player = get_node("raBIT/AnimationPlayer")  # Updated path to match scene
	agent = get_node("NavigationAgent3D")
	detection_area = get_node("Area3D") if detection_area == null else detection_area  # Initialize if not set
	
	# Configure detection area properly
	if detection_area:
		var collision_shape = detection_area.get_node("CollisionShape3D")
		if collision_shape and collision_shape.shape is BoxShape3D:
			# Set a reasonable detection range
			collision_shape.shape.size = Vector3(detection_range, 4.0, detection_range)
			collision_shape.position = Vector3(0, 2, 0)  # Center it on the enemy
			print("[raBIT] Detection area configured with range: ", detection_range)
	
	# Wait for navigation to be ready
	await get_tree().create_timer(0.5).timeout
	
	if agent == null:
		print("[raBIT ERROR] NavigationAgent3D not found - disabling enemy")
		is_active = false
		return
	
	# Configure navigation agent
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 1.0
	agent.path_max_distance = 1.0
	agent.max_speed = chase_speed
	agent.avoidance_enabled = true
	agent.radius = 0.4
	agent.height = 2.0
	
	call_deferred("set_initial_position")

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true
		print("[raBIT] Navigation ready at position: ", global_transform.origin)

func _physics_process(delta: float) -> void:
	if not is_active or not nav_ready or agent == null:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	# Detection phase
	if not has_seen_player:
		var spotted = detect_player()
		if spotted:
			has_seen_player = true
			player = spotted
			print("[raBIT] Player detected! Starting pursuit.")
			# Don't set velocity to zero when not seeing player - let them patrol or idle
	
	# Chase phase
	if has_seen_player and is_instance_valid(player) and not player.dead:
		chase_player(delta)
	else:
		# Lost player or player dead
		if has_seen_player:
			print("[raBIT] Lost player or player dead")
			has_seen_player = false
			player = null
		local_velocity.x = 0
		local_velocity.z = 0
	
	# Apply movement
	velocity.x = local_velocity.x
	velocity.z = local_velocity.z
	move_and_slide()
	
	# Update animation
	handle_animation()

func chase_player(delta: float) -> void:
	if not is_instance_valid(player) or player.dead or agent == null:
		return
	
	path_update_timer += delta
	if path_update_timer >= path_update_cooldown:
		path_update_timer = 0.0
		
		# Try to find a path that avoids the player's viewcone
		var target_position = find_best_target_position()
		
		if target_position != Vector3.ZERO:
			agent.target_position = target_position
			
			# Debug visualization
			if debug_visual_colors:
				print("[raBIT] Target position: ", target_position)
	
	# Follow the path
	update_path_following(chase_speed)

func find_best_target_position() -> Vector3:
	if not is_instance_valid(player):
		return Vector3.ZERO
	
	# Get the camera to determine where the player is looking
	var camera = player.get_node_or_null("Head/Camera3D")
	if not camera:
		print("[raBIT] Warning: Could not find player camera for target calculation")
		return Vector3.ZERO
	
	# Calculate position behind where the player is LOOKING (camera direction)
	var camera_forward = -camera.global_transform.basis.z.normalized()
	var camera_right = camera.global_transform.basis.x.normalized()
	var behind_offset = 3.0  # Distance behind player's view
	
	# Try multiple positions to find one outside the viewcone
	var test_positions = []
	
	# Primary target: directly behind where the player is looking
	test_positions.append(player.global_transform.origin - camera_forward * behind_offset)
	
	# Alternative targets: to the sides behind the player's view
	test_positions.append(player.global_transform.origin - camera_forward * behind_offset + camera_right * 2.5)
	test_positions.append(player.global_transform.origin - camera_forward * behind_offset - camera_right * 2.5)
	
	# More alternatives: directly to the sides
	test_positions.append(player.global_transform.origin + camera_right * 4.0)
	test_positions.append(player.global_transform.origin - camera_right * 4.0)
	
	# Even more alternatives: further behind
	test_positions.append(player.global_transform.origin - camera_forward * 5.0)
	
	# Find the best position that's navigable and outside viewcone
	for i in range(test_positions.size()):
		var test_pos = test_positions[i]
		# Snap to navigation mesh
		var nav_map = agent.get_navigation_map()
		var snapped_pos = NavigationServer3D.map_get_closest_point(nav_map, test_pos)
		
		# Check if position is valid and outside viewcone
		if snapped_pos.distance_to(test_pos) < 2.0:  # Position is on navmesh
			var in_viewcone = is_point_in_viewcone(snapped_pos, player)
			if debug_visual_colors:
				print("[raBIT] Testing position ", i, ": ", snapped_pos, " - In viewcone: ", in_viewcone)
			
			if not in_viewcone:
				# This position works!
				print("[raBIT] Found safe position outside viewcone at index ", i)
				return snapped_pos
	
	# If no position outside viewcone found, just go behind where player is looking
	# This is not ideal but better than not moving at all
	var fallback_pos = player.global_transform.origin - camera_forward * behind_offset
	print("[raBIT] Warning: No position outside viewcone found, using fallback behind camera view")
	return NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), fallback_pos)

func is_point_in_viewcone(point: Vector3, player_obj: Player) -> bool:
	if not is_instance_valid(player_obj):
		return false
	
	# Get the camera from the player
	var camera = player_obj.get_node_or_null("Head/Camera3D")
	if not camera:
		print("[raBIT] Warning: Could not find player camera")
		return false
	
	# Use camera position for viewcone origin
	var camera_pos = camera.global_transform.origin
	var to_point = point - camera_pos
	var distance = to_point.length()
	
	# Check distance
	if distance > view_range:
		return false
	
	# Get camera forward direction (negative Z in camera space)
	var camera_forward = -camera.global_transform.basis.z.normalized()
	
	# Project to horizontal plane for angle calculation
	var to_point_horizontal = Vector3(to_point.x, 0, to_point.z).normalized()
	var camera_forward_horizontal = Vector3(camera_forward.x, 0, camera_forward.z).normalized()
	
	if to_point_horizontal.length() < 0.1:  # Too close, consider in viewcone
		return true
	
	# Calculate angle between camera forward and direction to point
	var angle = rad_to_deg(camera_forward_horizontal.angle_to(to_point_horizontal))
	
	# Debug output
	if debug_visual_colors:
		print("[raBIT] Viewcone check - Angle: ", angle, " degrees (max: ", view_angle / 2.0, ")")
	
	if angle > view_angle / 2.0:
		return false
	
	# Check line of sight from camera to point
	return has_line_of_sight_to_point(camera_pos, point)

func has_line_of_sight_to_point(from: Vector3, to: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self.get_rid(), player.get_rid() if is_instance_valid(player) else RID()]
	query.collision_mask = 1  # Only check against static geometry
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func path_exposes_to_viewcone(path: Array, player: Player) -> bool:
	for i in range(1, path.size()):
		if is_point_in_viewcone(path[i], player):
			return true
	if path.size() > 0 and is_point_in_viewcone(path[path.size()-1], player):
		return true
	return false

func update_path_following(speed: float) -> void:
	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		
		# Check if we're about to enter the viewcone
		if is_point_in_viewcone(global_transform.origin, player):
			# We're in the viewcone! Stop and recalculate
			print("[raBIT] Entered viewcone while moving! Stopping.")
			local_velocity.x = 0
			local_velocity.z = 0
			path_update_timer = path_update_cooldown  # Force immediate recalculation
			return
		
		# Check if next position would put us in viewcone
		if is_point_in_viewcone(next_pos, player):
			# Next position is in viewcone, stop here
			print("[raBIT] Next position would enter viewcone! Stopping.")
			local_velocity.x = 0
			local_velocity.z = 0
			path_update_timer = path_update_cooldown  # Force immediate recalculation
			return
		
		var direction = (next_pos - global_transform.origin).normalized()
		direction.y = 0  # Keep movement horizontal
		
		if direction.length() > 0.1:
			local_velocity.x = direction.x * speed
			local_velocity.z = direction.z * speed
			
			# Smooth rotation towards movement direction
			var look_target = global_transform.origin + direction
			look_at(look_target, Vector3.UP)
	else:
		# Reached target or no path
		local_velocity.x = 0
		local_velocity.z = 0

func handle_animation() -> void:
	if animation_player == null:
		return
	
	var horizontal_speed = Vector2(local_velocity.x, local_velocity.z).length()
	var should_walk = horizontal_speed > 0.1
	
	if should_walk and not is_walking:
		is_walking = true
		animation_player.play("Walking")
	
	elif not should_walk and is_walking:
		is_walking = false
		animation_player.stop()

func _on_timer_timeout() -> void:
	if not is_active:
		return
	if !is_instance_valid(player) or player.dead:
		return
	
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist < attack_radius and has_seen_player:
		player.init_take_damage(attack_damage)
		$AttackSound.play()

func detect_player() -> CharacterBody3D:
	if detection_area == null:
		return null
	
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("players") and not body.dead:
			# Check line of sight
			if has_line_of_sight_to(body):
				return body
	return null

func has_line_of_sight_to(target: CharacterBody3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin + Vector3(0, 1, 0),  # Raise ray origin slightly
		target.global_transform.origin + Vector3(0, 1, 0)
	)
	query.exclude = [self.get_rid()]
	query.collision_mask = 1  # Only check against static geometry
	
	var result = space_state.intersect_ray(query)
	return result.is_empty() or result.collider == target
