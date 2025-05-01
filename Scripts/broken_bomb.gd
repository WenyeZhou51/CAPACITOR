class_name BrokenBomb extends Pickapable

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
	# Call the parent _ready function to add to scrap group
	super()
	
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
		flash_light.visible = false
		add_child(flash_light)
	else:
		flash_light = get_node("FlashLight")
	
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
			
			# Increase flash intensity
			if flash_light:
				flash_light.light_energy = lerp(0.2, 1.0, elapsed_time / explosion_time)

func interact(player: Player) -> void:
	# Start the timer when picked up if not already started
	if !timer_started:
		timer_started = true
		if flash_light:
			flash_light.visible = true
		
		# Start the beep timer
		beep_timer.wait_time = current_beep_interval
		beep_timer.start()
		
		print("Bomb timer started!")
	
	# Call the parent interact function to handle pickup
	super.interact(player)

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
		
		var tween = create_tween()
		tween.tween_property(flash_light, "light_energy", 0.0, 1.0)
		tween.tween_callback(flash_light.queue_free)
	
	# Deal damage to nearby players
	var space_state = get_world_3d().direct_space_state
	var players = get_tree().get_nodes_in_group("players")
	
	for player_node in players:
		if player_node is CharacterBody3D and !player_node.dead:
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

# Create a static version for inventory
func convert_rigidbody_to_staticbody(rigidbody: RigidBody3D) -> StaticBody3D:
	var static_body = super.convert_rigidbody_to_staticbody(rigidbody)
	
	# Add script to handle the bomb functionality when static
	var bomb_static_script = load("res://Scripts/broken_bomb_static.gd")
	if bomb_static_script:
		static_body.set_script(bomb_static_script)
		print("Adding broken bomb static script to object")
		
		# Transfer timer state
		static_body.timer_started = timer_started
		static_body.elapsed_time = elapsed_time
		static_body.explosion_time = explosion_time
		static_body.is_exploded = is_exploded
	
	return static_body 
