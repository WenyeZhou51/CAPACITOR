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

# State variables
var player: CharacterBody3D
var animation_player: AnimationPlayer
var agent: NavigationAgent3D
var local_velocity: Vector3 = Vector3.ZERO
var is_walking: bool = false
var nav_ready: bool = false
#var has_seen_player: bool = false
var is_active: bool = false 
var path_update_cooldown = 0.5
var path_update_timer = 0.0
var los_cooldown = 0.5
var los_timer = 0.0
var los

func _ready() -> void:
	print("[EARWORM] _ready() called")
	randomize()
	EarwormManager.get_instance().connect("sound_made", _on_sound_made)
	
	#delay timer
	var timer = Timer.new()
	timer.wait_time = randf_range(1, 2)#should be 10, 20
	timer.one_shot = true
	timer.timeout.connect(_on_activation_timeout)
	add_child(timer)
	timer.start()
	
	# Node initialization debug
	#animation_player = get_node("Venus/AnimationPlayer")
	agent = get_node("NavigationAgent3D")
	print("[👂🪱] Nodes initialized - AnimationPlayer: ", animation_player, " | Agent: ", agent)
	
	await get_tree().physics_frame
	print("[👂🪱] Physics frame awaited")
	
	if agent:
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = 0.5
		agent.max_speed = chase_speed
		print("[👂🪱] Agent configured | Speed: ", chase_speed, 
			" | Path Distance: ", agent.path_desired_distance,
			" | Target Distance: ", agent.target_desired_distance)
	
	# Player detection debug
	var players = get_tree().get_nodes_in_group("players")
	#print("[VENUS] Found ", players.size(), " players in group")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
		#print("[VENUS] Player assigned: ", player, " | Position: ", player.global_transform.origin)

	if agent:
		agent.target_position = global_transform.origin
		#print("[VENUS] Initial target position: ", agent.target_position)
		call_deferred("set_initial_position")

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true
		#print("[VENUS] Navigation ready | Position: ", agent.target_position, 
		#	" | Nav Ready: ", nav_ready, 
		#	" | Global Position: ", global_transform.origin)

func _physics_process(delta: float) -> void:
	
	#print("\n[VENUS] _physics_process() | Delta: ", delta)
	#print("[STATE] Nav Ready: ", nav_ready, 
	#	" | Player Valid: ", player != null, 
		#" | Velocity: ", local_velocity)
	if not is_active:
		return
	
	if not nav_ready or player == null:
		#print("[ERROR] Skipping physics - Nav Ready: ", nav_ready, " | Player: ", player)
		return
	
	# Gravity system debug
	var pre_gravity_y = local_velocity.y
	local_velocity.y -= gravity * delta
	#print("[GRAVITY] Applied: ", gravity * delta, 
		#" | Pre: ", pre_gravity_y, 
	#	" | Post: ", local_velocity.y, 
	#	" | On Floor: ", is_on_floor())
	
	if is_on_floor():
		local_velocity.y = max(local_velocity.y, 0)
		#print("[FLOOR] Velocity clamped to: ", local_velocity.y)
	
	#chase_player(delta)
	
	# Movement debug
	var pre_move_velocity = velocity
	velocity = local_velocity
	move_and_slide()
	local_velocity = velocity
	#print("[MOVEMENT] Pre: ", pre_move_velocity, 
		#" | Post: ", local_velocity, 
	#	" | Slide Count: ", get_slide_collision_count())
		

#func chase_player(delta: float) -> void:
	#path_update_timer += delta
	#if path_update_timer >= path_update_cooldown:
		#agent.target_position = player.global_transform.origin
		#update_path_following(chase_speed)  # Missing this call
		#path_update_timer = 0.0

func update_path_following(speed: float) -> void:
	#print("[PATH] Navigation finished: ", agent.is_navigation_finished())
	
	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var current_pos = global_transform.origin
		var offset_3d = next_pos - current_pos
		var offset_2d = Vector3(offset_3d.x, 0, offset_3d.z)
		var offset_length = offset_2d.length()
		
		#print("[PATH] Next Position: ", next_pos, 
		#	" | Current Position: ", current_pos, 
			#" | Offset 2D: ", offset_2d, 
		#	" | Length: ", offset_length)
		
		if offset_length > 0.01:
			var direction = offset_2d.normalized()
			#print("[MOVEMENT] Direction: ", direction, " | Speed: ", speed)
			
			var old_y = local_velocity.y
			local_velocity = direction * speed
			local_velocity.y = old_y
			#print("[VELOCITY] New Velocity: ", local_velocity)
			
			var look_target = global_transform.origin + direction
			#print("[ROTATION] Looking at: ", look_target)
			look_at(look_target, Vector3.UP)
		else:
			#print("[PATH] Reached waypoint - Zeroing velocity")
			local_velocity = Vector3.ZERO

func _on_timer_timeout() -> void:
	if not is_active:  # Add this check
		return
	#print("\n[ATTACK] Timer timeout")
	if !is_instance_valid(player):
		#print("[ATTACK] !!! Invalid player !!!")
		return
	
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	#print("[ATTACK] Distance: ", dist, " | Radius: ", attack_radius)
	
	if dist < attack_radius:
		#print("[ATTACK] !!! Hitting player !!!")
		player.take_damage(attack_damage)
		$AttackSound.play()

func _on_sound_made(sound_position: Vector3):
	# Check if sound is within hearing range
	#var distance = global_position.distance_to(sound_position)
	
	print("[👂🪱] 👂 heard sound >:)")
	
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true

func _on_activation_timeout() -> void:
	is_active = true
	print("[EARWORM] Activation timer finished - Starting chase behavior")
