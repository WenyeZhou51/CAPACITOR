extends CharacterBody3D

##
# 1) Expose properties
##
@export var gravity: float = 9.8
@export var normal_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var player_detection_range: float = 50.0
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

var is_walking: bool = false

var local_velocity: Vector3 = Vector3.ZERO

##
# 3) Ready function
##
func _ready() -> void:
	randomize()

	animation_player = get_node("Venus/AnimationPlayer")
	agent = get_node("../NavigationAgent3D")

	# Find player in group
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
	else:
		print("No player found in group 'players'.")

	if animation_player:
		animation_player.speed_scale = animation_speed

	# Initialize timings
	wander_time_left = randf_range(10.0, 15.0)
	next_wander_target_time = randf_range(3.0, 7.0)
	current_state = States.WANDER

	agent.max_speed = normal_speed
	agent.target_position = global_transform.origin  # Start at the current position

##
# 4) Physics process
##
func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Apply gravity manually
	if not is_on_floor():
		local_velocity.y -= gravity * delta
	else:
		local_velocity.y = 0.0

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

	local_velocity = velocity

	handle_animation()

##
# 5) State processors
##
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

func process_chase(delta: float) -> void:
	agent.target_position = player.global_transform.origin
	update_path_following(chase_speed)

	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist > player_detection_range or not has_line_of_sight():
		set_state(States.SEARCH)

##
# 6) State setter
##
func set_state(new_state: int) -> void:
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
	var random_x = randf_range(-20.0, 20.0)
	var random_z = randf_range(-20.0, 20.0)
	agent.target_position = global_transform.origin + Vector3(random_x, 0, random_z)

func update_path_following(speed: float) -> void:
	if not agent.is_navigation_finished():
		var next_position = agent.get_next_path_position()

		var direction = next_position - global_transform.origin
		direction.y = 0.0

		if direction.length() > 0.1:
			direction = direction.normalized()

			look_at(global_transform.origin + direction, Vector3.UP)

			local_velocity.x = direction.x * speed
			local_velocity.z = direction.z * speed
		else:

			stop_movement()
	else:
		stop_movement()

##
# 8) Utility helpers
##
func has_line_of_sight() -> bool:
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist > player_detection_range:
		return false

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = global_transform.origin
	query.to = player.global_transform.origin
	query.exclude = [self]
	query.collision_mask = 0xFFFFFFFF  

	var hit = space_state.intersect_ray(query)
	if hit and hit.collider == player:
		return true
	return false

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
