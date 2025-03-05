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

# Adjust these constants for performance
@export var path_update_interval: float = 0.1  # How often to update navigation path
@export var sound_cleanup_interval: float = 0.5  # How often to clean up old sounds
@export var wander_interval: float = 2.0  # Increased from 3.0 to reduce updates

# State variables
var player: CharacterBody3D
var animation_player: AnimationPlayer
var agent: NavigationAgent3D
var local_velocity: Vector3 = Vector3.ZERO
var is_walking: bool = false
var nav_ready: bool = false
var is_active: bool = false 
var path_update_cooldown = 0.5
var path_update_timer = 0.0
var los_cooldown = 0.5
var los_timer = 0.0
var los
var wander_timer: float = 0.0
var wander_radius: float = 10.0
var current_target: Vector3
var heard_sounds: Array[Dictionary] = []
var current_sound: Dictionary = {}

# Add these variables
var sound_cleanup_timer: float = 0.0
var path_timer: float = 0.0

# Add these variables near the top with other state variables
@onready var walk_sound = $WalkSound
@onready var alert_sound = $AlertSound
@onready var attack_sound = $AttackSound
@onready var earworm_model = $EarwormModel

# Animation variables
var animation_name: String = ""
var is_animation_playing: bool = false

# Add these variables near the top with other state variables
var investigation_timer: float = 0.0
const INVESTIGATION_DURATION: float = 2.0  # How long to investigate each sound
var is_investigating: bool = false
var investigation_target: Vector3

# Add these near the top with other exports
@export var attack_interval: float = 1.0  # Time between attacks
@export var attack_range: float = 2.0  # Range at which earworm can attack

# Add these with other state variables
var can_attack: bool = true
var attack_timer: float = 0.0

# Add these variables near the top with other state variables
var time_without_sounds: float = 0.0
const WANDER_START_DELAY: float = 1.0  # Time to wait before wandering after no sounds
const WANDER_RADIUS: float = 15.0  # Maximum distance for wander targets
const WANDER_SPEED_MULTIPLIER: float = 0.3  # 30% of normal speed when wandering

# Add these variables near the top with other state variables
var current_sound_target: Vector3
var is_investigating_sound: bool = false

# Add this near the top with other state variables
var alert_sound_cooldown: float = 0.0
const ALERT_SOUND_INTERVAL: float = 3.0  # Minimum time between alert sounds (increased from 1.0)

# Add this near other state variables
var has_wander_target: bool = false

# Add near other state variables
var current_wander_target: Vector3
var is_wandering: bool = false

# Add these constants at top of file
const DEBUG_NAV = true
const DEBUG_PATH = true
const DEBUG_WANDER = true
const DEBUG_STATE = true
const DEBUG_PHYSICS = true  # New debug category for physics/collision issues

# Add these constants near other wander-related constants
const MIN_WANDER_INTERVAL: float = 4.0  # Minimum time before picking new wander point
const MAX_WANDER_INTERVAL: float = 7.0  # Maximum time before picking new wander point
const MIN_WANDER_DISTANCE: float = 5.0  # Minimum distance for wander target
const MAX_WANDER_DISTANCE: float = 12.0  # Maximum distance for wander target

# Add this variable with other state variables
var next_wander_time: float = 0.0

# Add this function
func debug_log(category: String, message: String) -> void:
	if (category == "NAV" and DEBUG_NAV) or \
	   (category == "PATH" and DEBUG_PATH) or \
	   (category == "WANDER" and DEBUG_WANDER) or \
	   (category == "STATE" and DEBUG_STATE):
		print("[DEBUG-" + category + "] " + message)

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
	# Get the AnimationPlayer from the FBX model
	animation_player = earworm_model.get_node("AnimationPlayer")
	agent = $NavigationAgent3D
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
	if players.size() > 0:
		player = players[0] as CharacterBody3D

	if agent:
		agent.target_position = global_transform.origin
		call_deferred("set_initial_position")

	# Connect collision signal
	connect("body_entered", _on_collision)
	
	# Start playing animation immediately and continuously
	if animation_player:
		# Get the first animation from the animation player
		var animations = animation_player.get_animation_list()
		print("[EARWORM] Available animations: ", animations)
		if animations.size() > 0:
			animation_name = animations[0]  # Use the first available animation
			animation_player.play(animation_name)
			animation_player.set_speed_scale(1.0)
			is_animation_playing = true
			print("[EARWORM] Started playing animation: ", animation_name)
		else:
			print("[EARWORM] No animations found in the animation player")

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true

func _physics_process(delta: float) -> void:
	if not is_active or not nav_ready:
		return
	
	# Ensure animation is always playing
	if animation_player and not animation_player.is_playing() and animation_name != "":
		animation_player.play(animation_name)
		is_animation_playing = true
	
	# Handle attack if close to player
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < attack_radius and can_attack:
			attack_player()
	
	# Update alert sound cooldown
	if alert_sound_cooldown > 0:
		alert_sound_cooldown -= delta
	
	# Update attack cooldown
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_interval:
			can_attack = true
			attack_timer = 0.0
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y > 0:
			velocity.y = 0  # Never allow upward movement
	else:
		velocity.y = 0  # Reset vertical velocity when on floor
	
	# Update path timer
	path_timer += delta
	if path_timer >= path_update_interval:
		path_timer = 0.0
		
		# If we have a sound, prioritize it
		if not current_sound.is_empty():
			print("[EARWORM] Following sound at: ", current_sound["position"])
			current_sound_target = current_sound["position"]
			agent.target_position = current_sound_target
			is_investigating_sound = true
			is_wandering = false
			time_without_sounds = 0.0
			update_path_following(chase_speed)
		else:
			# Update time without sounds
			time_without_sounds += path_update_interval
			
			# If we're investigating a sound location but reached it
			if is_investigating_sound and agent.is_navigation_finished():
				print("[EARWORM] Finished investigating sound, switching to wander")
				is_investigating_sound = false
				current_sound.clear()  # Clear the current sound to prevent re-investigation
				time_without_sounds = WANDER_START_DELAY  # Force wander state to start
			
			# Count down next wander time if we're wandering
			if is_wandering:
				next_wander_time -= delta
				print("[EARWORM] Next wander in: ", next_wander_time)
			
			# If enough time has passed without sounds, start wandering
			if time_without_sounds >= WANDER_START_DELAY:
				if not is_wandering or agent.is_navigation_finished() or next_wander_time <= 0:
					wander()
				else:
					update_path_following(chase_speed * WANDER_SPEED_MULTIPLIER)
			# Continue investigating current sound if we're still on it
			elif is_investigating_sound:
				update_path_following(chase_speed)
	
	# Move using physics
	move_and_slide()
	
	# Reset horizontal velocity if not moving
	if abs(velocity.x) < 0.1 and abs(velocity.z) < 0.1:
		velocity.x = 0
		velocity.z = 0
	
	# Debug logs
	print("[EARWORM] State: ", 
		"Investigating" if is_investigating_sound else 
		"Wandering" if is_wandering else "Idle",
		" | Has Sound: ", not current_sound.is_empty())

func update_path_following(speed: float) -> void:
	if not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var current_pos = global_transform.origin
		var offset_3d = next_pos - current_pos
		
		# ADDED: Debug raw navigation target
		print("[NAV POSITION DEBUG] Current Y: ", current_pos.y,
			" | Target Y: ", next_pos.y,
			" | Y Difference: ", next_pos.y - current_pos.y)
		
		# MODIFIED: Explicitly ignore Y component for movement calculation
		# This ensures the earworm only moves horizontally, letting physics handle slopes
		var direction = Vector3(offset_3d.x, 0, offset_3d.z).normalized()
		var offset_length = Vector3(offset_3d.x, 0, offset_3d.z).length()
		
		# Lower the threshold significantly
		if offset_length > 0.05:  # Changed from 0.5 to 0.05
			# Only set X and Z components, NEVER set Y velocity for navigation
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			# IMPORTANT: Never allow navigation to cause vertical movement
			# Y velocity is handled exclusively by gravity and floor detection
			
			# ADDED: Debug navigation velocity changes
			print("[NAV VELOCITY DEBUG] Setting velocity from nav | X: ", velocity.x, 
				" | Z: ", velocity.z, 
				" | Y unchanged: ", velocity.y)
			
			# Store horizontal movement in local_velocity
			local_velocity.x = direction.x * speed
			local_velocity.z = direction.z * speed
			
			# Play walk sound when moving
			if not walk_sound.playing:
				walk_sound.play()
			
			# Make the earworm face the direction it's moving
			if direction != Vector3.ZERO:
				var look_at_pos = global_position + direction
				# Only rotate around Y axis
				look_at_pos.y = global_position.y
				look_at(look_at_pos)
				
				# Apply smooth rotation
				var target_basis = transform.basis
				transform.basis = transform.basis.slerp(target_basis, turn_speed * get_process_delta_time())
		else:
			# Only zero out horizontal movement
			velocity.x = 0
			velocity.z = 0
			local_velocity.x = 0
			local_velocity.z = 0
			walk_sound.stop()

		print("[PATH DEBUG] Offset Length: ", offset_length,
			  " | Local Velocity: ", local_velocity,
			  " | Global Pos: ", global_position,
			  " | Next Pos: ", next_pos)

		print("[NAV DEBUG] Distance to target: ", global_position.distance_to(current_wander_target),
			  " | Path Distance: ", agent.path_desired_distance,
			  " | Target Distance: ", agent.target_desired_distance,
			  " | Nav Finished: ", agent.is_navigation_finished())

func _on_sound_made(sound_position: Vector3, radius: float):
	var distance = global_position.distance_to(sound_position)
	print("[EARWORM] Sound detected - Position: ", sound_position, " | Radius: ", radius, " | Distance: ", distance)
	
	if distance <= radius:
		is_wandering = false  # Reset wandering state when hearing a sound
		wander_timer = 0.0
		# Play alert sound when hearing something (with cooldown)
		if alert_sound and not alert_sound.playing and alert_sound_cooldown <= 0:
			print("[EARWORM] Alert sound playing - detected noise")
			alert_sound.play()
			alert_sound_cooldown = ALERT_SOUND_INTERVAL
		
		time_without_sounds = 0.0  # Reset the timer when hearing a sound
		
		# Store the new sound
		current_sound = {
			"position": sound_position,
			"distance": distance
		}
		
		# Set the target position immediately
		if agent and nav_ready:
			current_sound_target = sound_position
			agent.target_position = current_sound_target
			is_investigating_sound = true
			print("[EARWORM] Investigating sound at: ", current_sound_target)
	else:
		print("[EARWORM] Sound too far away to hear: ", distance, " > ", radius)

func _on_activation_timeout() -> void:
	is_active = true
	print("[EARWORM] Activation timer finished - Starting chase behavior")

func wander() -> void:
	if not nav_ready:
		return
	
	print("[EARWORM] Selecting new wander target")
	
	# Clear all other states
	is_investigating_sound = false
	current_sound.clear()
	
	# Set wander state
	is_wandering = true
	
	# Set next wander time
	next_wander_time = randf_range(MIN_WANDER_INTERVAL, MAX_WANDER_INTERVAL)
	print("[EARWORM] Next wander target in: ", next_wander_time, " seconds")
	
	# Generate a random direction
	var random_direction = Vector3(
		randf_range(-1.0, 1.0),
		0.0,  # Keep on same Y level
		randf_range(-1.0, 1.0)
	).normalized()
	
	# Generate a random distance
	var random_distance = randf_range(MIN_WANDER_DISTANCE, MAX_WANDER_DISTANCE)
	
	# Calculate new target position
	current_wander_target = global_position + (random_direction * random_distance)
	
	# Set the navigation target
	agent.target_position = current_wander_target
	print("[EARWORM] New wander target set: ", current_wander_target, " (", random_distance, " units away)")
	
	# Start moving toward the target
	update_path_following(chase_speed * WANDER_SPEED_MULTIPLIER)

func attack_player() -> void:
	if not player or not is_instance_valid(player) or not can_attack:
		return
		
	var dist = global_position.distance_to(player.global_position)
	if dist < attack_radius and has_line_of_sight():
		print("[EARWORM] Attacking player - accidentally found them!")
		
		# Set attack cooldown
		can_attack = false
		attack_timer = 0.0
		
		# Apply damage and play sound
		player.take_damage(attack_damage)
		if attack_sound:
			attack_sound.play()
			
		# Important: DON'T change the navigation target to the player
		# This ensures we don't track the player after attacking
		# We only attack when we "accidentally" find the player while 
		# following sounds or wandering

# Add near the top with other constants
const ATTACK_DAMAGE: float = 100.0
const ATTACK_INTERVAL: float = 1.0  # Time between attacks

# Add this new function to handle collisions
func _on_collision(body: Node) -> void:
	pass  # We're handling attacks in attack_player() instead

func has_line_of_sight() -> bool:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		player.global_position
	)
	var result = space.intersect_ray(query)
	return result.is_empty() or result.collider == player

# Add near other collision-related functions
func _on_navigation_finished() -> void:
	# ADDED: Debug navigation completion
	print("[NAV DEBUG] Navigation finished | Position Y: ", global_position.y,
		" | On Floor: ", is_on_floor(), 
		" | Target Y: ", agent.target_position.y if agent else "No agent",
		" | Y Difference: ", (agent.target_position.y - global_position.y) if agent else "N/A")
