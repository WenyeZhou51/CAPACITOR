extends CharacterBody3D

@export var gravity: float = 9.8
@export var chase_speed: float = 6.0
@export var turn_speed: float = 2.0
@export var attack_radius: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0

@export var debug_visual_colors: bool = false

@export var animation_speed: float = 8.0
@export var chase_animation_speed: float = 16.0

var player: CharacterBody3D
var animation_player: AnimationPlayer
var agent: NavigationAgent3D

var local_velocity: Vector3 = Vector3.ZERO
var is_walking: bool = false
var nav_ready: bool = false

func _ready() -> void:
	randomize()

	#animation_player = get_node("Venus/AnimationPlayer")
	agent = get_node("NavigationAgent3D")

	# Wait one physics frame before configuring agent
	await get_tree().physics_frame

	if agent:
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = 0.5
		agent.max_speed = chase_speed  # Always use chase speed

	# Find a player in the "players" group
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
		print("Player found.")
	else:
		print("No player found in group 'players'.")

	# Set animation speed to chase speed by default
	if animation_player:
		animation_player.speed_scale = chase_animation_speed

	# Set an initial target so the agent can start pathfinding
	if agent:
		agent.target_position = global_transform.origin
		call_deferred("set_initial_position")

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true

func _physics_process(delta: float) -> void:
	if not nav_ready or player == null:
		return

	# Apply gravity
	if not is_on_floor():
		local_velocity.y -= gravity * delta
	else:
		local_velocity.y = 0.0

	# Always chase the player
	chase_player()

	velocity = local_velocity
	move_and_slide()
	local_velocity = velocity

	# Handle walking animation
	handle_animation()

	# Update debug color if enabled
	if debug_visual_colors:
		_update_debug_color()

func chase_player() -> void:
	if agent:
		agent.target_position = player.global_transform.origin
		update_path_following(chase_speed)

func update_path_following(speed: float) -> void:
	# If the agent hasn't reached the end of the path
	if not agent.is_navigation_finished():
		var next_position = agent.get_next_path_position()
		var offset_3d = next_position - global_transform.origin
		var offset_2d = offset_3d
		offset_2d.y = 0

		# Calculate direction
		var direction_2d = offset_2d.normalized()
		var old_y = local_velocity.y
		local_velocity = direction_2d * speed
		local_velocity.y = old_y

		# Rotate towards the movement direction
		look_at(global_transform.origin + direction_2d, Vector3.UP)
	else:
		# If the path is finished, do nothing special,
		# so the enemy won't artificially stop.
		pass

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

func _update_debug_color():
	var chase_color = Color(1, 0, 0)  # e.g., Red for "Chase"
	var mesh_instance_path = "Venus/rig/Skeleton3D/Cube"
	var mesh_instance = get_node_or_null(mesh_instance_path)
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = mesh_instance.get_active_material(0)
		if material and material is StandardMaterial3D:
			var mat := material as StandardMaterial3D
			mat.albedo_color = chase_color

# Attack if near player (no line_of_sight check)
func _on_timer_timeout() -> void:
	if !is_instance_valid(player):
		return

	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist < attack_radius:
		player.take_damage(attack_damage)
		$AttackSound.play()
		print("ATTACKING!!")
