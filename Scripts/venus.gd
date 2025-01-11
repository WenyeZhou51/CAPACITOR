extends CharacterBody3D

##
# 1) Expose properties
##
@export var gravity: float = 9.8
@export var normal_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var player_detection_range: float = 100.0
@export var turn_speed: float = 2.0
@export var animation_speed: float = 8.0
@export var chase_animation_speed: float = 16.0

##
# 2) Define states & timers
##
enum States { WANDER, SEARCH, CHASE }
var current_state: int = States.WANDER

var wander_time_left: float = 0.0
var next_wander_target_time: float = 0.0
var search_time_left: float = 0.0

var player: CharacterBody3D
var animation_player: AnimationPlayer
var agent: NavigationAgent3D
var nav_ready: bool = false

var is_walking: bool = false
var local_velocity: Vector3 = Vector3.ZERO

##
# 3) Ready function
##
func _ready() -> void:
	print("[DEBUG] Entered _ready()")
	randomize()
	print("[DEBUG] Random seed set.")

	animation_player = get_node("Venus/AnimationPlayer")
	agent = get_node("NavigationAgent3D")
	print("[DEBUG] AnimationPlayer and NavigationAgent3D references acquired.")

	await get_tree().physics_frame
	
	if agent:
		print("[DEBUG] Configuring NavigationAgent3D with path/target distances & max_speed.")
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = 0.5
		agent.max_speed = normal_speed

	# Find player in group
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
		print("player found")
	else:
		print("No player found in group 'players'.")
		push_warning("[WARNING] Could not find any nodes in 'players' group.")

	if animation_player:
		animation_player.speed_scale = animation_speed

	# Initialize timings
	wander_time_left = randf_range(10.0, 15.0)
	next_wander_target_time = randf_range(3.0, 7.0)
	current_state = States.WANDER

	if agent:
		agent.target_position = global_transform.origin
		call_deferred("set_initial_position")

func set_initial_position() -> void:
	print("[DEBUG] Entered set_initial_position()")
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true
		print("[DEBUG] Agent target_position set, nav_ready = true")

##
# 4) Physics process
##
func _physics_process(delta: float) -> void:
	print("[DEBUG] _physics_process called with delta = ", delta)
	if not nav_ready or player == null:
		print("[DEBUG] Early return from _physics_process (nav_ready:", nav_ready, ", player == null:", player == null, ")")
		return

	# Apply gravity manually
	if not is_on_floor():
		local_velocity.y -= gravity * delta
	else:
		local_velocity.y = 0.0
	print("[DEBUG] current state is:",current_state)
	# Handle state logic
	match current_state:
		
		States.WANDER:
			process_wander(delta)
			
		States.SEARCH:
			process_search(delta)
		States.CHASE:
			process_chase(delta)
	velocity = local_velocity

	move_and_slide()

	# After movement, store the final velocity back to local_velocity:
	local_velocity = velocity

	handle_animation()

##
# 5) State processors
##
func process_wander(delta: float) -> void:
	print("[DEBUG] process_wander called, wander_time_left =", wander_time_left, "next_wander_target_time =", next_wander_target_time)
	wander_time_left -= delta
	next_wander_target_time -= delta

	if wander_time_left <= 0.0:
		set_state(States.SEARCH)
		return

	if next_wander_target_time <= 0.0:
		pick_random_wander_target()
		next_wander_target_time = randf_range(3.0, 7.0)

	update_path_following(normal_speed)
	if has_line_of_sight():
		set_state(States.CHASE)

func process_search(delta: float) -> void:
	print("[DEBUG] process_search called, search_time_left =", search_time_left)
	search_time_left -= delta
	agent.target_position = player.global_transform.origin

	if search_time_left <= 0.0:
		set_state(States.WANDER)
		return

	update_path_following(normal_speed)
	if has_line_of_sight():
		set_state(States.CHASE)

func process_chase(delta: float) -> void:
	print("[DEBUG] process_chase called")
	agent.target_position = player.global_transform.origin
	print("[DEBUG] my position", global_transform.origin)
	print("[DEBUG] chasing to position", player.global_transform.origin)
	update_path_following(chase_speed)

	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist > player_detection_range or not has_line_of_sight():
		set_state(States.SEARCH)

##
# 6) State setter
##
func set_state(new_state: int) -> void:
	print("[DEBUG] Changing state from", current_state, "to", new_state)
	current_state = new_state
	match current_state:
		States.WANDER:
			wander_time_left = randf_range(10.0, 15.0)
			next_wander_target_time = randf_range(3.0, 7.0)
			agent.max_speed = normal_speed
			pick_random_wander_target()
			if animation_player:
				animation_player.speed_scale = animation_speed

		States.SEARCH:
			search_time_left = 5.0
			agent.max_speed = normal_speed
			if animation_player:
				animation_player.speed_scale = animation_speed

		States.CHASE:
			agent.max_speed = chase_speed
			if animation_player:
				animation_player.speed_scale = chase_animation_speed

##
# 7) Pathfinding helpers
##
func pick_random_wander_target() -> void:
	print("[DEBUG] pick_random_wander_target() called")
	var random_x = randf_range(-20.0, 20.0)
	var random_z = randf_range(-20.0, 20.0)
	agent.target_position = global_transform.origin + Vector3(random_x, 0, random_z)
func update_path_following(speed: float) -> void:
	print("[DEBUG] update_path_following called with speed:", speed)

	if not agent.is_navigation_finished():
		var next_position = agent.get_next_path_position()
		print("[DEBUG] Current agent position:", global_transform.origin)
		print("[DEBUG] Next path position:", next_position)
		print("[DEBUG] Current State:", current_state)
		print("[DEBUG] Player position:", player.global_transform.origin)

		# 1) Compute the raw 3D offset.
		var offset_3d = next_position - global_transform.origin

		# 2) Flatten the Y for both direction *and* distance
		#    (since we’re ignoring vertical offsets for 'chase' logic).
		var offset_2d = offset_3d
		offset_2d.y = 0

		var dist_2d = offset_2d.length()
		print("[DEBUG] Flattened offset_2d:", offset_2d, " dist_2d:", dist_2d)

		# 3) If we’re horizontally close enough, consider this waypoint reached.
		#    This prevents flipping back and forth around a tiny XZ difference.
		if dist_2d < agent.path_desired_distance:
			# (By default, if path_desired_distance = 0.5, this
			#  should be enough to let you skip to the next waypoint.)
			print("[DEBUG] Close enough to waypoint; no movement this frame.")
			stop_movement()
			return

		# 4) Otherwise, move in XZ toward the waypoint.
		#    (We keep the Y velocity from gravity in _physics_process().)
		var direction_2d = offset_2d.normalized()
		var old_y = local_velocity.y   # preserve vertical motion from gravity

		local_velocity = direction_2d * speed
		local_velocity.y = old_y

		# 5) Turn to face the direction of travel (only around the Y axis).
		var look_dir = direction_2d.normalized()
		look_at(global_transform.origin + look_dir, Vector3.UP)

		print("[DEBUG] Updated local_velocity:", local_velocity)
	else:
		print("[DEBUG] Navigation finished or no path available.")
		stop_movement()




##
# 8) Utility helpers
##
func has_line_of_sight() -> bool:
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	print("[DEBUG] Checking line of sight; distance to player =", dist)
	if dist > player_detection_range:
		push_warning("[WARNING] Player is out of detection range.")
		return false

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin,
		player.global_transform.origin,
		0xFFFFFFFF,
		[self]
	)

	var hit = space_state.intersect_ray(query)
	return hit and hit.collider == player

func stop_movement() -> void:
	print("[DEBUG] stop_movement() called. Setting local_velocity.x and .z to 0.")
	local_velocity.x = 0
	local_velocity.z = 0
	if is_walking:
		is_walking = false
		if animation_player:
			animation_player.stop()

func handle_animation() -> void:
	var horizontal_speed = Vector2(local_velocity.x, local_velocity.z).length()
	var should_walk = horizontal_speed > 0.1

	if should_walk and not is_walking:
		print("[DEBUG] handle_animation -> Starting walk animation.")
		is_walking = true
		if animation_player:
			animation_player.play("Walking")
	elif not should_walk and is_walking:
		print("[DEBUG] handle_animation -> Stopping walk animation.")
		is_walking = false
		if animation_player:
			animation_player.stop()
