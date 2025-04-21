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
@export var collision_area: Area3D

# Adjust these constants for performance
@export var path_update_interval: float = 0.1  # How often to update navigation path
@export var sound_cleanup_interval: float = 0.5  # How often to clean up old sounds
@export var wander_interval: float = 2.0  # Increased from 3.0 to reduce updates
#@export var detection_area: Area3D

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
const ATTACK_DAMAGE: float = 20.0
const ATTACK_INTERVAL: float = 1.0  # Time between attacks

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
	
	collision_area.connect("body_entered", Callable(self, "_on_collision"))
	
	# Node initialization debug
	# Get the AnimationPlayer from the FBX model
	animation_player = earworm_model.get_node("AnimationPlayer")
	agent = $NavigationAgent3D
	print("[EARWORM] Nodes initialized - AnimationPlayer: ", animation_player, " | Agent: ", agent)
	
	await get_tree().physics_frame
	print("[EARWORM] Physics frame awaited")
	
	if agent:
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = 0.5
		agent.max_speed = chase_speed
		print("[EARWORM] Agent configured | Speed: ", chase_speed, 
			" | Path Distance: ", agent.path_desired_distance,
			" | Target Distance: ", agent.target_desired_distance)
	
	# Player detection debug
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0] as CharacterBody3D

	if agent:
		agent.target_position = global_transform.origin
		call_deferred("set_initial_position")

	## Connect collision signal
	#connect("body_entered", _on_collision)
	
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
	
	# Make the earworm model respond to lighting
	setup_lighting_responsive_material()

func set_initial_position() -> void:
	if agent:
		agent.target_position = global_transform.origin
		nav_ready = true

func _physics_process(delta: float) -> void:

	if not is_active or not nav_ready:
		return

	# (Optional: ensure animation is always playing)
	# if animation_player and not animation_player.is_playing() and animation_name != "":
	#     animation_player.play(animation_name)
	#     is_animation_playing = true

	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		# if can_attack:
		#     attack_player()

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

		if is_investigating_sound and agent.is_navigation_finished():
			print("Earworm has reached origin of sound")
			animation_player.stop()
			velocity.x = 0
			velocity.z = 0
			walk_sound.stop()
			is_investigating_sound = false
			current_sound.clear()
			time_without_sounds = WANDER_START_DELAY
		elif not current_sound.is_empty():
			current_sound_target = current_sound["position"]
			agent.target_position = current_sound_target
			is_investigating_sound = true
			is_wandering = false
			time_without_sounds = 0.0
			update_path_following(chase_speed, delta)
		elif is_investigating_sound:
			update_path_following(chase_speed, delta)

	# Move using physics
	move_and_slide()

	# Reset horizontal velocity if almost zero
	if abs(velocity.x) < 0.1 and abs(velocity.z) < 0.1:
		velocity.x = 0
		velocity.z = 0

func update_path_following(speed: float, delta: float) -> void:
	# Only update if there is still a path to follow.
	if agent.is_navigation_finished():
		return

	# Play the walking animation if needed.
	if animation_player and animation_name != "" and not animation_player.is_playing():
		animation_player.play(animation_name)

	var next_pos = agent.get_next_path_position()
	var current_pos = global_transform.origin
	var offset_3d = next_pos - current_pos
	var horizontal_offset = Vector3(offset_3d.x, 0, offset_3d.z)
	var distance_to_next = horizontal_offset.length()

	# FIX: If the enemy is close enough, stop all movement and clear investigation state.
	if distance_to_next < 0.5:
		velocity.x = 0
		velocity.z = 0
		local_velocity.x = 0
		local_velocity.z = 0
		walk_sound.stop()
		animation_player.stop()
		current_sound.clear()
		is_investigating_sound = false
		return

	# Otherwise, continue moving toward the target.
	var direction = horizontal_offset.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	local_velocity.x = direction.x * speed
	local_velocity.z = direction.z * speed

	# Rotate enemy to face movement direction (only on Y axis)
	if direction != Vector3.ZERO:
		var look_at_pos = global_position + direction
		look_at_pos.y = global_position.y
		look_at(look_at_pos)
		
		# Smooth rotation toward the direction
		var target_basis = Basis().looking_at(direction, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, turn_speed * delta)

	# Play walk sound when moving
	if not walk_sound.playing:
		walk_sound.play()

func _on_sound_made(sound_position: Vector3, radius: float) -> void:
	# Check if the sound is within range (requires a valid player).
	player = findPlayer()
	if player == null:
		print("[EARWORM] Sound too far away to hear")
		return

	is_wandering = false  # Reset wandering state upon hearing a sound
	wander_timer = 0.0
	# Play alert sound (with cooldown) when a sound is detected.
	if alert_sound and not alert_sound.playing and alert_sound_cooldown <= 0:
		alert_sound.play()
		alert_sound_cooldown = ALERT_SOUND_INTERVAL

	time_without_sounds = 0.0  # Reset the no-sound timer
	
	# Set the new sound as the target.
	current_sound = { "position": sound_position }
	
	# Set the target position immediately.
	if agent and nav_ready:
		current_sound_target = sound_position
		agent.target_position = current_sound_target
		is_investigating_sound = true
		print("[EARWORM] Investigating sound at: ", current_sound_target)

func _on_activation_timeout() -> void:
	is_active = true


# Add this new function to handle collisions
func _on_collision(body: CharacterBody3D) -> void:
	print("Colliding with: ", body)
	if body.is_in_group("players") and not body.dead:
		# Immediately deal damage if cooldown has expired.
		if can_attack:
			print("[EARWORM] Immediate collision with player, attacking.")
			body.init_take_damage(attack_damage)
			if attack_sound:
				attack_sound.play()
		else:
			print("[EARWORM] Attack on cooldown.")
		
		# Create a Timer node to handle continuous damage after the initial hit.
		# (Only one timer is created per collision event, assuming the Area3D handles it once.)
		var timer = Timer.new()
		timer.wait_time = attack_interval  # delay between repeated attacks
		timer.one_shot = false
		add_child(timer)
		timer.start()
		
		# Connect the timer's timeout signal with an inline function (lambda)
		timer.timeout.connect(func():
			# Check if the player is still colliding and alive
			if body in collision_area.get_overlapping_bodies() and not body.dead:
				print("[EARWORM] Continuous collision with player, attacking.")
				body.init_take_damage(attack_damage)
				if attack_sound:
					attack_sound.play()
			else:
				# If no longer colliding or player is dead, stop and remove the timer
				timer.stop()
				timer.queue_free()
		)

func findPlayer() -> CharacterBody3D:
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		print("Found: ", body)
		if body.is_in_group("players") and !body.dead:
			print("Found player, in pursuit")
			return body
	return null

func has_line_of_sight() -> bool:
	player = findPlayer()
	if(player == null):
		return false

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

# Add this new function to set up the material
func setup_lighting_responsive_material():
	print("[EARWORM] Setting up lighting-responsive material")
	
	# Find all mesh instances in the model
	var mesh_instances = []
	find_mesh_instances(earworm_model, mesh_instances)
	
	print("[EARWORM] Found " + str(mesh_instances.size()) + " mesh instances")
	
	# Apply lighting-responsive material to each mesh
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			print("[EARWORM] Processing mesh: " + mesh_instance.name)
			
			# Create a new StandardMaterial3D
			var material = StandardMaterial3D.new()
			
			# Get the existing material if any
			var existing_material = null
			if mesh_instance.get_surface_override_material_count() > 0:
				existing_material = mesh_instance.get_surface_override_material(0)
			elif mesh_instance.mesh.get_surface_count() > 0 and mesh_instance.mesh.surface_get_material(0):
				existing_material = mesh_instance.mesh.surface_get_material(0)
			
			# Copy properties from existing material if possible
			if existing_material and existing_material is StandardMaterial3D:
				if existing_material.albedo_texture:
					material.albedo_texture = existing_material.albedo_texture
				material.albedo_color = existing_material.albedo_color
			
			# Configure the material to respond to lighting
			material.roughness = 0.7
			material.metallic = 0.0
			material.emission_enabled = false
			
			# Apply the material
			mesh_instance.material_override = material
			print("[EARWORM] Applied lighting-responsive material to " + mesh_instance.name)

# Helper function to find all mesh instances in a node hierarchy
func find_mesh_instances(node, result_array):
	if node is MeshInstance3D:
		result_array.append(node)
	
	for child in node.get_children():
		find_mesh_instances(child, result_array)

func handle_sound_emission(sound_position: Vector3, radius: float) -> void:
	# Only process sounds on the server
	if not is_multiplayer_authority():
		return
	
	# Existing sound handling logic
	var distance = global_position.distance_to(sound_position)
	if distance <= radius * 2.0:
		heard_sounds.append({
			"position": sound_position,
			"timestamp": Time.get_unix_time_from_system()
		})
