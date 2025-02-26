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
#var has_seen_player: bool = false
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

	# Connect collision signal
	connect("body_entered", _on_collision)

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true
		#print("[VENUS] Navigation ready | Position: ", agent.target_position, 
		#	" | Nav Ready: ", nav_ready, 
		#	" | Global Position: ", global_transform.origin)

func _physics_process(delta: float) -> void:
	print("Active:", is_active, " | Nav Ready:", nav_ready)
	if not is_active or not nav_ready:
		return
	
	# ADDED: Debug physics state before any changes
	print("[PHYSICS DEBUG] Before Physics | Position Y: ", global_position.y, 
		" | Velocity Y: ", velocity.y,
		" | Local Velocity Y: ", local_velocity.y)
	print("[COLLISION DEBUG] Floor: ", is_on_floor(), 
		" | Wall: ", is_on_wall(), 
		" | Ceiling: ", is_on_ceiling())
	
	# Add this near the start of _physics_process to check for player collision
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < attack_radius and can_attack:
			attack_player()
	
	# Update alert sound cooldown
	if alert_sound_cooldown > 0:
		alert_sound_cooldown -= delta
	
	# Update timers
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_interval:
			can_attack = true
			attack_timer = 0.0
	
	# MODIFIED: Strengthen gravity to keep the earworm grounded
	# Only allow downward movement (falling), never upward movement
	if not is_on_floor():
		# Apply stronger gravity to keep it grounded
		velocity.y -= gravity * 3.0 * delta  # Triple gravity for faster grounding
		print("[GRAVITY DEBUG] Applying gravity: ", gravity * 3.0 * delta, 
			" | New Velocity Y: ", velocity.y)
		# Restrict upward velocity
		if velocity.y > 0:
			velocity.y = 0  # Never allow upward movement
	else:
		velocity.y = 0  # Reset vertical velocity when on floor
		print("[GRAVITY DEBUG] On floor, resetting Y velocity to 0")
	
	# Update path timer
	path_timer += delta
	if path_timer >= path_update_interval:
		path_timer = 0.0
		
		# If we have a sound and aren't already investigating it
		if not current_sound.is_empty() and not is_investigating_sound:
			print("heard sound")
			current_sound_target = current_sound["position"]
			agent.target_position = current_sound_target
			is_investigating_sound = true
			is_wandering = false
			time_without_sounds = 0.0
			update_path_following(chase_speed)
		else:
			# Only handle non-wandering state
			if not is_wandering:
				time_without_sounds += path_update_interval
				
				if time_without_sounds >= WANDER_START_DELAY:
					wander()
				elif is_investigating_sound:
					# Add navigation check before path following
					if agent.is_navigation_finished():
						is_investigating_sound = false
						current_sound.clear()
					else:
						update_path_following(chase_speed)
				else:
					# Full state reset
					is_investigating_sound = false
					current_sound.clear()
					is_wandering = false  # Add explicit wandering reset

			# Add wandering state maintenance
			else:
				# Check if it's time to pick a new wander target
				next_wander_time -= delta
				if next_wander_time <= 0 or agent.is_navigation_finished():
					wander()  # Get new wander target
				else:
					update_path_following(chase_speed * WANDER_SPEED_MULTIPLIER)

	# ADDED: Debug before move_and_slide
	print("[PHYSICS DEBUG] Before move_and_slide | Position: ", global_position, 
		" | Velocity: ", velocity)
	
	# Apply movement
	move_and_slide()
	
	# ADDED: Debug after move_and_slide
	print("[PHYSICS DEBUG] After move_and_slide | Position: ", global_position, 
		" | Velocity: ", velocity,
		" | Floor: ", is_on_floor(),
		" | Wall: ", is_on_wall())
	print("[COLLISION DEBUG] Collider Count: ", get_slide_collision_count())
	
	# Log all collisions in this frame
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		print("[COLLISION DEBUG] Collision ", i, 
			" | Normal: ", collision.get_normal(),
			" | Collider: ", collision.get_collider().name if collision.get_collider() else "None")
	
	# MODIFIED: Force the earworm to stay grounded after movement
	# Apply a snap to the ground after moving to prevent any floating
	if not is_on_floor():
		# Add a small downward position adjustment to help stay grounded
		var snap_vector = Vector3(0, -0.1, 0)
		global_position += snap_vector
		print("[GROUNDING DEBUG] Applied snap to ground: ", snap_vector)
	
	# Reset horizontal components if not moving
	if abs(local_velocity.x) < 0.1 and abs(local_velocity.z) < 0.1:
		velocity.x = 0
		velocity.z = 0
	
	# IMPORTANT: Always zero out upward velocity to prevent any jumping
	if velocity.y > 0:
		velocity.y = 0
	
	# Update local_velocity with current velocity for next frame
	local_velocity = velocity
	
	# ADDED: Debug final state
	print("[PHYSICS DEBUG] End of Frame | Position Y: ", global_position.y, 
		" | Velocity Y: ", velocity.y,
		" | On Floor: ", is_on_floor())

	# Restore the original state debug print
	print("[STATE DEBUG] Time Without Sounds: ", time_without_sounds,
		  " | Is Investigating: ", is_investigating_sound,
		  " | Is Wandering: ", is_wandering,
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
			
			# Improved rotation logic
			var target_basis = Basis().looking_at(direction)
			var target_transform = Transform3D(target_basis, global_position)
			# Increase turn_speed for smoother rotation
			transform = transform.interpolate_with(target_transform, get_process_delta_time() * turn_speed * 3.0)
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
	
	if distance <= radius:
		is_wandering = false  # Reset wandering state when hearing a sound
		wander_timer = 0.0
		# Play alert sound when hearing something (with cooldown)
		if alert_sound and not alert_sound.playing and alert_sound_cooldown <= 0:
			alert_sound.play()
			alert_sound_cooldown = ALERT_SOUND_INTERVAL
		
		time_without_sounds = 0.0  # Reset the timer when hearing a sound
		
		# Store the new sound
		current_sound = {
			"position": sound_position,
			"distance": distance
		}

func _on_activation_timeout() -> void:
	is_active = true
	print("[EARWORM] Activation timer finished - Starting chase behavior")

func wander() -> void:
	if not nav_ready:
		return
	
	# ADDED: Debug wander entry
	print("[WANDER DEBUG] Starting wander | Current position Y: ", global_position.y,
		" | On Floor: ", is_on_floor(),
		" | Current Velocity Y: ", velocity.y)
	
	# Clear all other states first
	is_investigating_sound = false
	current_sound.clear()
	
	# Set next wander time whether entering wander state or picking new target
	next_wander_time = randf_range(MIN_WANDER_INTERVAL, MAX_WANDER_INTERVAL)
	
	if not is_wandering:
		debug_log("WANDER", "Entering wander state")
		is_wandering = true
	
	# Try to find a valid wander position (max 5 attempts)
	var valid_position = false
	var attempts = 0
	while not valid_position and attempts < 5:
		# Generate random point within distance range
		var random_angle = randf() * PI * 2
		var random_radius = randf_range(MIN_WANDER_DISTANCE, MAX_WANDER_DISTANCE)
		var offset = Vector3(
			cos(random_angle) * random_radius,
			0,  # Keep Y at 0 to avoid vertical issues
			sin(random_angle) * random_radius
		)
		
		# MODIFIED: Use current Y position for wander target to stay at same height
		current_wander_target = Vector3(
			global_position.x + offset.x,
			global_position.y,  # Keep exact same Y position
			global_position.z + offset.z
		)
		
		# ADDED: Debug wander target
		print("[WANDER DEBUG] Potential target | Y: ", current_wander_target.y,
			" | Original Y: ", global_position.y,
			" | Difference: ", current_wander_target.y - global_position.y)
		
		agent.target_position = current_wander_target
		
		# Wait a frame to let the navigation system update
		await get_tree().physics_frame
		
		# Check if point is navigable
		if agent.is_target_reachable():
			valid_position = true
			debug_log("WANDER", "Found valid wander target at: " + str(current_wander_target) + 
					 " | Next change in: " + str(next_wander_time) + " seconds")
		else:
			attempts += 1
			debug_log("WANDER", "Invalid wander target, attempt " + str(attempts))
	
	if valid_position:
		# ADDED: Debug final wander target
		print("[WANDER DEBUG] Final valid target | Y: ", current_wander_target.y,
			" | Distance: ", global_position.distance_to(current_wander_target))
		
		# Target is already set, just start moving
		time_without_sounds = 0.0
		update_path_following(chase_speed * WANDER_SPEED_MULTIPLIER)
	else:
		# If no valid position found, stay in place briefly before trying again
		debug_log("WANDER", "No valid wander target found, will retry in 2 seconds")
		is_wandering = true  # Stay in wandering state
		current_wander_target = global_position
		agent.target_position = current_wander_target
		next_wander_time = 2.0  # Try again in 2 seconds
	
	# Stop walk sound when starting new wander
	walk_sound.stop()

func attack_player() -> void:
	if not player or not is_instance_valid(player) or not can_attack:
		return
		
	var dist = global_position.distance_to(player.global_position)
	if dist < attack_radius and has_line_of_sight():
		# Set attack cooldown
		can_attack = false
		attack_timer = 0.0
		
		# Play attack animation if we have one
		if animation_player and animation_player.has_animation("Attack"):
			animation_player.stop()  # Stop any current animation
			animation_player.play("Attack")
		
		# Apply damage and play sound
		player.take_damage(attack_damage)
		attack_sound.play()

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
