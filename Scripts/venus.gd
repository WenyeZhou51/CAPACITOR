extends CharacterBody3D

@export var gravity: float = 9.8
@export var normal_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var player_detection_range: float = 100.0
@export var turn_speed: float = 2.0
@export var animation_speed: float = 8.0
@export var chase_animation_speed: float = 16.0

# debug colors
@export var debug_visual_colors: bool = false

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

# This timer tracks how long we have currently lost LOS during CHASE.
var lost_sight_timer: float = 0.0

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

func _physics_process(delta: float) -> void:
	if not nav_ready or player == null:
		return

	# Apply gravity
	if not is_on_floor():
		local_velocity.y -= gravity * delta
	else:
		local_velocity.y = 0.0

	match current_state:
		States.WANDER:
			process_wander(delta)
		States.SEARCH:
			process_search(delta)
		States.CHASE:
			process_chase(delta)

	velocity = local_velocity
	move_and_slide()
	local_velocity = velocity

	handle_animation()

	# If debug colors are enabled, color the enemy model.
	if debug_visual_colors:
		_update_debug_color()

func process_wander(delta: float) -> void:
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
	search_time_left -= delta
	agent.target_position = player.global_transform.origin

	if search_time_left <= 0.0:
		set_state(States.WANDER)
		return

	update_path_following(normal_speed)
	if has_line_of_sight():
		set_state(States.CHASE)

@warning_ignore("unused_parameter")
func process_chase(delta: float) -> void:
	# If we still see the player, chase; otherwise begin a 1s countdown.
	if has_line_of_sight():
		lost_sight_timer = 0.0
	else:
		lost_sight_timer += delta

	agent.target_position = player.global_transform.origin
	update_path_following(chase_speed)

	var dist = global_transform.origin.distance_to(player.global_transform.origin)

	# If too far or we lost line of sight for a full second, revert to searching
	if dist > player_detection_range or lost_sight_timer >= 1.0:
		set_state(States.SEARCH)

func set_state(new_state: int) -> void:
	print("[DEBUG] Changing state from", current_state, "to", new_state)
	current_state = new_state

	match current_state:
		States.WANDER:
			wander_time_left = randf_range(10.0, 15.0)
			next_wander_target_time = randf_range(3.0, 7.0)
			if agent:
				agent.max_speed = normal_speed
			pick_random_wander_target()
			if animation_player:
				animation_player.speed_scale = animation_speed

		States.SEARCH:
			# "search_time_left" is the short period to wander near the player
			search_time_left = 5.0
			if agent:
				agent.max_speed = normal_speed
			if animation_player:
				animation_player.speed_scale = animation_speed

		States.CHASE:
			lost_sight_timer = 0.0
			if agent:
				agent.max_speed = chase_speed
			if animation_player:
				animation_player.speed_scale = chase_animation_speed

func pick_random_wander_target() -> void:
	var random_x = randf_range(-20.0, 20.0)
	var random_z = randf_range(-20.0, 20.0)
	agent.target_position = global_transform.origin + Vector3(random_x, 0, random_z)

func update_path_following(speed: float) -> void:
	if not agent.is_navigation_finished():
		var next_position = agent.get_next_path_position()
		var offset_3d = next_position - global_transform.origin
		var offset_2d = offset_3d
		offset_2d.y = 0
		var dist_2d = offset_2d.length()

		if dist_2d < agent.path_desired_distance:
			stop_movement()
			return

		var direction_2d = offset_2d.normalized()
		var old_y = local_velocity.y
		local_velocity = direction_2d * speed
		local_velocity.y = old_y
		var look_dir = direction_2d.normalized()
		look_at(global_transform.origin + look_dir, Vector3.UP)
	else:
		stop_movement()

func has_line_of_sight() -> bool:
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist > player_detection_range:
		return false

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_transform.origin, player.global_transform.origin, 0xFFFFFFFF, [self])
	var hit = space_state.intersect_ray(query)
	return hit and hit.collider == player

func stop_movement() -> void:
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
		is_walking = true
		if animation_player:
			animation_player.play("Walking")
	elif not should_walk and is_walking:
		is_walking = false
		if animation_player:
			animation_player.stop()

# Helper for debug coloring
func _update_debug_color():
	var color_map = {
		States.WANDER: Color(0, 1, 0),
		States.SEARCH: Color(1, 1, 0),
		States.CHASE:  Color(1, 0, 0),
	}
	var color = color_map.get(current_state, Color(1, 1, 1))

	# Path to the MeshInstance3D node
	var mesh_instance_path = "Venus/rig/Skeleton3D/Cube"
	var mesh_instance = get_node_or_null(mesh_instance_path)

	# Check if the mesh instance exists
	if mesh_instance == null:
		print("Debug: MeshInstance3D node not found at path:", mesh_instance_path)
		return

	# Ensure the node is a MeshInstance3D
	if not (mesh_instance is MeshInstance3D):
		print("Debug: Node found at path is not a MeshInstance3D:", mesh_instance_path)
		return

	# Check for the active material and modify its color
	var material = mesh_instance.get_active_material(0)
	if material == null:
		print("Debug: No material found on the MeshInstance3D node at path:", mesh_instance_path)
		return

	if not (material is StandardMaterial3D):
		print("Debug: Material is not a StandardMaterial3D at path:", mesh_instance_path)
		return

	# Apply the color to the material
	var mat := material as StandardMaterial3D
	mat.albedo_color = color
	print("Debug: Updated material color to:", color)
