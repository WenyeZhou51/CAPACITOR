extends CharacterBody3D

# Existing exports
@export var gravity: float = 9.8
@export var chase_speed: float = 6.0 # originally 6. 0 for dbg
@export var turn_speed: float = 2.0
@export var attack_radius: float = 3.0 # originally 3
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var debug_visual_colors: bool = false
@export var animation_speed: float = 8.0
@export var chase_animation_speed: float = 16.0
@export var detection_area: Area3D

# State variables
var player: CharacterBody3D
var animation_player: AnimationPlayer
var run_animation_player: AnimationPlayer
var attack_animation_player: AnimationPlayer
var agent: NavigationAgent3D
var local_velocity: Vector3 = Vector3.ZERO
var is_walking: bool = false
var nav_ready: bool = false
var has_seen_player: bool = false
var is_active: bool = true
var path_update_cooldown = 0.5
var path_update_timer = 0.0
var los_cooldown = 0.5
var los_timer = 0.0
var los

# BLACKOUT specific variables
var run_model: Node3D
var attack_model: Node3D
var is_attacking: bool = false
var attack_animation_time: float = 1.0  # Time in seconds for attack animation
var attack_timer: float = 0.0

func _ready() -> void:
	print("[BLACKOUT] _ready() called")
	randomize()
	
	# Delay timer
	var timer = Timer.new()
	timer.wait_time = randf_range(20, 40)  # Should be 20, 40
	timer.one_shot = true
	timer.timeout.connect(_on_activation_timeout)
	add_child(timer)
	timer.start()
	
	# Get references to models
	run_model = get_node("BLACKOUT_RUN")
	attack_model = get_node("BLACKOUT_ATTACK")
	
	# Get animation players from both models
	if run_model:
		run_animation_player = run_model.get_node_or_null("AnimationPlayer")
		if run_animation_player:
			print("[BLACKOUT] Run model animations: ", run_animation_player.get_animation_list())
			
			# Print details about each animation
			for anim_name in run_animation_player.get_animation_list():
				var anim = run_animation_player.get_animation(anim_name)
				print("[BLACKOUT] Animation '", anim_name, "' length: ", anim.length, " tracks: ", anim.get_track_count())
				
				# Print track names
				for i in range(anim.get_track_count()):
					print("[BLACKOUT] Track ", i, " path: ", anim.track_get_path(i))
	
	if attack_model:
		attack_animation_player = attack_model.get_node_or_null("AnimationPlayer")
		if attack_animation_player:
			print("[BLACKOUT] Attack model animations: ", attack_animation_player.get_animation_list())
	
	# Make sure run model is visible and attack model is hidden initially
	if run_model:
		run_model.visible = true
	if attack_model:
		attack_model.visible = false
	
	# Get animation player
	animation_player = get_node("AnimationPlayer")
	agent = get_node("NavigationAgent3D")
	print("[BLACKOUT] Nodes initialized - AnimationPlayer: ", animation_player, 
		" | Run Model: ", run_model, 
		" | Attack Model: ", attack_model, 
		" | Agent: ", agent)
	
	await get_tree().physics_frame
	print("[BLACKOUT] Physics frame awaited")
	
	if agent:
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = 0.5
		agent.max_speed = chase_speed
		print("[BLACKOUT] Agent configured | Speed: ", chase_speed, 
			" | Path Distance: ", agent.path_desired_distance,
			" | Target Distance: ", agent.target_desired_distance)
	
	# Player detection debug
	var players = get_tree().get_nodes_in_group("players")
	
	# Animation debug
	if animation_player:
		animation_player.speed_scale = chase_animation_speed
		print("[BLACKOUT] Animation speed set to: ", chase_animation_speed)
		
		# Check available animations
		print("[BLACKOUT] Available animations: ", animation_player.get_animation_list())
	
	if agent:
		agent.target_position = global_transform.origin
		call_deferred("set_initial_position")

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	
	if not nav_ready:
		return
	
	# Update attack timer if attacking
	if is_attacking:
		attack_timer += delta
		if attack_timer >= attack_animation_time:
			is_attacking = false
			attack_timer = 0.0
			# Switch back to run model
			if run_model:
				run_model.visible = true
			if attack_model:
				attack_model.visible = false
	
	# Gravity system
	local_velocity.y -= gravity * delta
	
	if is_on_floor():
		local_velocity.y = max(local_velocity.y, 0)
	
	# Line of sight check
	if not has_seen_player:
		var spotted = has_line_of_sight()
		if spotted:
			has_seen_player = true
			# Assign the detected player so that chase functions know whom to follow.
			player = spotted
	
	# If a player has been spotted, start chasing them.
	if has_seen_player:
		if player and player.dead:
			print("successfully killed player")
			has_seen_player = false
		else:
			chase_player(delta)
			# Movement
			var pre_move_velocity = velocity
			velocity = local_velocity
			move_and_slide()
			local_velocity = velocity
			
			# Only handle animation if not attacking
			if not is_attacking:
				handle_animation()

func chase_player(delta: float) -> void:
	if not is_instance_valid(player) or player.dead:
		return
	
	path_update_timer += delta
	if path_update_timer >= path_update_cooldown:
		agent.target_position = player.global_transform.origin
		update_path_following(chase_speed)
		path_update_timer = 0.0

func update_path_following(speed: float) -> void:
	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var current_pos = global_transform.origin
		var offset_3d = next_pos - current_pos
		var offset_2d = Vector3(offset_3d.x, 0, offset_3d.z)
		var offset_length = offset_2d.length()
		
		if offset_length > 0.01:
			var direction = offset_2d.normalized()
			
			var old_y = local_velocity.y
			local_velocity = direction * speed
			local_velocity.y = old_y
			
			var look_target = global_transform.origin + direction
			look_at(look_target, Vector3.UP)
		else:
			local_velocity = Vector3.ZERO

func handle_animation() -> void:
	var horizontal_speed = Vector2(local_velocity.x, local_velocity.z).length()
	var should_walk = horizontal_speed > 0.1
	
	if should_walk and not is_walking:
		print("[BLACKOUT] Starting walk animation")
		is_walking = true
		# Make sure run model is visible
		if run_model:
			run_model.visible = true
		if attack_model:
			attack_model.visible = false
		
		# Try to play animation from the run model's animation player
		if run_animation_player and run_animation_player.get_animation_list().size() > 0:
			var anim_name = run_animation_player.get_animation_list()[0]
			print("[BLACKOUT] Playing run animation: ", anim_name)
			run_animation_player.play(anim_name)
		elif animation_player:
			animation_player.play("Walking")
			print("[BLACKOUT] Playing Walking animation from main AnimationPlayer")

	elif not should_walk and is_walking:
		print("[BLACKOUT] Stopping animation")
		is_walking = false
		if run_animation_player:
			run_animation_player.stop()
		if animation_player:
			animation_player.stop()

func play_attack_animation() -> void:
	print("[BLACKOUT] Playing attack animation")
	is_attacking = true
	attack_timer = 0.0
	
	# Switch to attack model
	if run_model:
		run_model.visible = false
	if attack_model:
		attack_model.visible = true
	
	# Try to play animation from the attack model's animation player
	if attack_animation_player and attack_animation_player.get_animation_list().size() > 0:
		var anim_name = attack_animation_player.get_animation_list()[0]
		print("[BLACKOUT] Playing attack animation: ", anim_name)
		attack_animation_player.play(anim_name)

func _on_timer_timeout() -> void:
	if not is_active:
		return
	
	if !is_instance_valid(player) or player.dead:
		return
	
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	
	if dist < attack_radius:
		print("[BLACKOUT] Attacking player!")
		player.init_take_damage(attack_damage)
		play_attack_animation()

func has_line_of_sight() -> CharacterBody3D:
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.is_in_group("players") and !body.dead:
			return body
	return null

func _on_activation_timeout() -> void:
	is_active = true
	print("[BLACKOUT] Activation timer finished - Starting chase behavior")
