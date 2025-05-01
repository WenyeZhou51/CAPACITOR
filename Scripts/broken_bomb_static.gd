class_name BrokenBombStatic extends Drop

var audio_player: AudioStreamPlayer3D
var timer_started: bool = false
var elapsed_time: float = 0.0
var flash_light: OmniLight3D
var explosion_particles: GPUParticles3D
var is_exploded: bool = false

# Timer for controlling beep frequency
var beep_timer: Timer
var current_beep_interval: float = 3.0
@export var explosion_time: float = 120.0  # Default 120 seconds
@export var final_beep_interval: float = 0.4  # Beep interval before rapid beeping
@export var damage_amount: int = 100
@export var explosion_radius: float = 5.0

func _ready() -> void:
	# Set the price
	Price = 700
	
	# Set the type
	type = "brokenbomb"
	
	# Create or get the audio player
	if !has_node("BeepSound"):
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "BeepSound"
		audio_player.max_distance = 20.0  # Adjust as needed
		add_child(audio_player)
		
		# Load the beep sound
		var sound = load("res://audio/beep sound.wav")
		if sound:
			audio_player.stream = sound
			print("Beep sound loaded successfully")
		else:
			print("Failed to load beep sound")
	else:
		audio_player = get_node("BeepSound")
	
	# Create or get the flash light
	if !has_node("FlashLight"):
		flash_light = OmniLight3D.new()
		flash_light.name = "FlashLight"
		flash_light.light_color = Color(1, 0, 0)  # Red light
		flash_light.light_energy = 0.2  # Start with faint light
		flash_light.omni_range = 2.0
		flash_light.visible = false  # Always off initially
		add_child(flash_light)
	else:
		flash_light = get_node("FlashLight")
		flash_light.visible = false  # Ensure light is off initially
	
	# Create explosion particles (will be invisible until explosion)
	if !has_node("ExplosionParticles"):
		explosion_particles = GPUParticles3D.new()
		explosion_particles.name = "ExplosionParticles"
		explosion_particles.emitting = false
		explosion_particles.one_shot = true
		explosion_particles.explosiveness = 1.0
		explosion_particles.amount = 100
		
		# Create a sphere shape for the particles
		var particle_material = ParticleProcessMaterial.new()
		particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		particle_material.emission_sphere_radius = 0.5
		particle_material.direction = Vector3(0, 1, 0)
		particle_material.spread = 180.0
		particle_material.gravity = Vector3(0, -1, 0)
		particle_material.initial_velocity_min = 5.0
		particle_material.initial_velocity_max = 10.0
		particle_material.scale_min = 0.5
		particle_material.scale_max = 1.5
		particle_material.color = Color(1, 0.5, 0, 1)  # Orange-red
		explosion_particles.process_material = particle_material
		
		# Create a mesh for the particles
		var particle_mesh = SphereMesh.new()
		particle_mesh.radius = 0.1
		particle_mesh.height = 0.2
		explosion_particles.draw_pass_1 = particle_mesh
		
		add_child(explosion_particles)
	else:
		explosion_particles = get_node("ExplosionParticles")
	
	# Create beep timer
	beep_timer = Timer.new()
	beep_timer.one_shot = true
	beep_timer.wait_time = current_beep_interval
	beep_timer.timeout.connect(_on_beep_timer_timeout)
	add_child(beep_timer)
	
	# Start the timer if it was already started
	if timer_started and !is_exploded:
		beep_timer.wait_time = current_beep_interval
		beep_timer.start()

func _process(delta: float) -> void:
	if timer_started and !is_exploded:
		elapsed_time += delta
		
		if elapsed_time >= explosion_time:
			if !is_exploded:
				explode()
		elif elapsed_time >= explosion_time - 2.0:
			# Final 2 seconds - rapid beeping
			current_beep_interval = 0.1
		else:
			# Gradually decrease beep interval from 3 seconds to final_beep_interval
			current_beep_interval = lerp(3.0, final_beep_interval, elapsed_time / explosion_time)
			
			# Don't keep the light on constantly - only during flashes
			# We'll handle light visibility in the _on_beep_timer_timeout function

func _on_beep_timer_timeout() -> void:
	if is_exploded:
		return
		
	# Play beep sound
	if audio_player and audio_player.stream:
		audio_player.play()
		
	# Flash the light
	if flash_light:
		flash_light.visible = true
		var tween = create_tween()
		tween.tween_property(flash_light, "light_energy", 0.0, 0.1)
		tween.tween_property(flash_light, "light_energy", lerp(0.2, 1.0, elapsed_time / explosion_time), 0.1)
		# Hide the light after a short flash
		tween.tween_callback(func(): flash_light.visible = false).set_delay(0.2)
	
	# Set up the next beep
	beep_timer.wait_time = current_beep_interval
	beep_timer.start()

func explode() -> void:
	is_exploded = true
	print("BOMB EXPLODED!")
	
	# Stop beeping
	if beep_timer:
		beep_timer.stop()
	
	# Play explosion sound
	var explosion_sound = AudioStreamPlayer3D.new()
	explosion_sound.name = "ExplosionSound"
	explosion_sound.max_distance = 50.0  # Can be heard from far away
	add_child(explosion_sound)
	
	var sound = load("res://audio/explode sound.flac")
	if sound:
		explosion_sound.stream = sound
		explosion_sound.play()
	
	# Show explosion particles
	if explosion_particles:
		explosion_particles.emitting = true
	
	# Create a bright flash
	if flash_light:
		flash_light.light_color = Color(1, 0.8, 0.2)  # Yellow-orange
		flash_light.light_energy = 5.0  # Very bright
		flash_light.omni_range = 10.0  # Larger range
		flash_light.visible = true  # Make sure it's visible for explosion
		
		var tween = create_tween()
		tween.tween_property(flash_light, "light_energy", 0.0, 1.0)
		tween.tween_callback(flash_light.queue_free)
	
	# Deal damage to nearby players
	var space_state = get_world_3d().direct_space_state
	var players = get_tree().get_nodes_in_group("players")
	
	# Get the player holding this bomb
	var holding_player = null
	if get_parent().name == "ItemSocket":
		holding_player = get_parent().get_parent().get_parent()
	
	for player_node in players:
		if player_node is CharacterBody3D and !player_node.dead:
			# If this player is holding the bomb, apply damage directly
			if player_node == holding_player:
				print("Player holding bomb, dealing full damage")
				player_node.init_take_damage(damage_amount)
			else:
				# Check distance for other players
				var distance = global_position.distance_to(player_node.global_position)
				
				if distance <= explosion_radius:
					# Check line of sight (optional)
					var query = PhysicsRayQueryParameters3D.create(
						global_position,
						player_node.global_position
					)
					query.exclude = [self]
					var result = space_state.intersect_ray(query)
					
					if result.is_empty() or result.collider == player_node:
						print("Player in explosion radius, dealing damage")
						player_node.init_take_damage(damage_amount)
	
	# Remove the bomb after a delay to allow particles and sound to finish
	var remove_timer = Timer.new()
	remove_timer.wait_time = 2.0
	remove_timer.one_shot = true
	remove_timer.timeout.connect(func(): queue_free())
	add_child(remove_timer)
	remove_timer.start()

func drop(player: CharacterBody3D, drop_position: Vector3 = Vector3.ZERO, drop_direction: Vector3 = Vector3.FORWARD) -> void:
	# Call the parent drop function 
	var world = get_tree().current_scene
	var item_socket = player.get_node("Head/ItemSocket")
	
	if self.get_parent() == item_socket:
		item_socket.remove_child(self)
		player._set_item_visibility(self, false, "before dropping")  # Hide before conversion
		
		var global_transform = player.global_transform
		self.global_transform.origin = global_transform.origin + (global_transform.basis.z * drop_direction * 2) + drop_position
		
		var rigidbody = convert_staticbody_to_rigidbody(self, world)
		
		# Transfer the timer state to the rigidbody
		if rigidbody is BrokenBomb:
			rigidbody.timer_started = timer_started
			rigidbody.elapsed_time = elapsed_time
			rigidbody.is_exploded = is_exploded
		
		world.add_child(rigidbody)
		# Add the dropped item to the scrap group for radar detection
		rigidbody.add_to_group("scrap")
		player._set_item_visibility(rigidbody, true, "dropped in world")
	
	# Clear from inventory
	for i in range(player.inventory.size()):
		if player.inventory[i] == self:
			player.inventory[i] = null
			player.inv_size -= 1
			if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
				GameState.change_ui.emit(i, "empty", 0)
			break
	player.is_holding = false

# Override this function to handle bomb-specific conversion
func convert_staticbody_to_rigidbody(static_body: StaticBody3D, world: Node3D) -> RigidBody3D:
	# Get the parent node
	var path = "res://Scenes/prefabs/items/" + str(static_body.type) + ".tscn"
	print("Attempting to load: ", path)
	
	# Create a new RigidBody3D from the scene
	var scene = load(path)
	if scene == null:
		push_error("Failed to load scene: " + path)
		print("ERROR: Cannot drop item - scene file not found: " + path)
		return null
	
	var rigidbody = scene.instantiate()
	rigidbody.name = static_body.name  # Retain the same name for clarity
	
	# Transfer the transform (position, rotation, scale)
	rigidbody.transform = static_body.transform
	
	# Set properties
	rigidbody.Price = static_body.Price
	rigidbody.type = static_body.type
	
	# Transfer bomb-specific properties
	if rigidbody is BrokenBomb:
		rigidbody.timer_started = timer_started
		rigidbody.elapsed_time = elapsed_time
		rigidbody.explosion_time = explosion_time
		rigidbody.is_exploded = is_exploded
		rigidbody.damage_amount = damage_amount
		rigidbody.explosion_radius = explosion_radius
		rigidbody.final_beep_interval = final_beep_interval
		print("Transferred bomb timer state: timer_started=", timer_started, ", elapsed_time=", elapsed_time)
	
	# Apply impulse to make it feel more natural
	if rigidbody is RigidBody3D:
		rigidbody.apply_impulse(Vector3(0, 2, -5))
	
	# Clean up the static body
	self.queue_free()
	
	print("Successfully dropped item as: " + rigidbody.name)
	return rigidbody 
