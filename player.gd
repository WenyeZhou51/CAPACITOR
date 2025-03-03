extends CharacterBody3D

class_name Player

# Constants
const WALK_SPEED = 3.5  # Default walking speed
const RUN_SPEED = 8.0  # Sprinting speed
const JUMP_FORCE = 6.5  # Force applied for jumping
const STAMINA_DRAIN_RATE = 0.01  #should be 0.3. for debug 0.01 Rate at which stamina drains while sprinting
const STAMINA_REGEN_RATE = 0.2  # Rate at which stamina regenerates while not sprinting
const GRAVITY_FORCE = Vector3.DOWN * 9.8 * 2  # Gravity vector
const STAMINA_THRESHOLD = 0.5  # Buffer threshold for stamina management

signal value_changed(new_value)
signal change_ui(idx, type)
signal inv_high(pI, cI, name)

# Variables
@export var stamina_bar: VSlider  # Reference to the stamina UI slider
@export var interaction_area: Area3D
@export var interact_label: Label
@export var texture_rect: TextureRect
@export var animation_player: AnimationPlayer
@export var bypass_material: ShaderMaterial
@export var min_vignette_intensity: float = 0.0
@export var max_vignette_intensity: float = 1.0
@export var min_noise_amount: float = 0.03
@export var max_noise_amount: float = 0.13
@export var min_scan_line_amount: float = 0.5
@export var max_scan_line_amount: float = 1.0
@export var player_mesh: GeometryInstance3D
@export var player_colors = [Color.RED, Color.BLUE] # , Color.WHITE, Color.GREEN, Color.YELLOW

@export var quota: int = 600 ## REPLACE WITH MULT MANAGER QUOTA

var current_stamina: float = 1.0 + STAMINA_THRESHOLD  # Current stamina level
var is_running: bool = false  # Whether the player is sprinting
var movement_speed: float = WALK_SPEED  # Current movement speed
var is_holding: bool = false # Whether the player is holding an intem
@export var current_health: float = 10.0 #### MUST HAVE EXPORT FOR SYNCING
var max_health: float = 100.0
var crt_shader_material: ShaderMaterial
var inv_size: int = 0
var currIdx: int
var is_jumping: bool = false

var inventory := [null, null, null, null]
var current_slot := 0
var score: int = 0
var popup_scene = preload("res://Scenes/pop_up.tscn")

var is_invincible: bool = false
var invincibility_timer: Timer
#for console interaction
var using_console: bool = false
var near_console: bool = false
var console_window: Control = null
var camera_locked: bool = false
var camera_target: Vector3
var popup_instance: Node
var dead = false
@onready var camera: Camera3D = $Head/Camera3D

# Sound players
var sprint_sound_player: AudioStreamPlayer
var drop_item_sound_player: AudioStreamPlayer
var flashlight_sound_player: AudioStreamPlayer
var cashin_sound_player: AudioStreamPlayer
var was_running: bool = false # Track previous running state

var sound_emitter: Node

func _ready():
	set_multiplayer_authority(str(name).to_int())
	add_to_group("players")
	stamina_bar = get_node("/root/Level/UI/SprintSlider")
	interact_label = get_node("/root/Level/UI/InteractLabel")
	texture_rect = get_node("/root/Level/UI/TextureRect")
	crt_shader_material = texture_rect.material
	var msg = "Collect a total scrap value of: " + str(GameState.get_quota())
	popup_instance = popup_scene.instantiate()
	popup_instance.popup_text = msg
	add_child(popup_instance)
	popup_instance.pop_up()
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.wait_time = 0.2
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	add_child(invincibility_timer)
	
	# Set up sound emitter
	sound_emitter = $SoundEmitter if has_node("SoundEmitter") else null
	if not sound_emitter:
		sound_emitter = Node.new()
		sound_emitter.set_script(load("res://Scripts/player_sound_emitter.gd"))
		sound_emitter.name = "SoundEmitter"
		add_child(sound_emitter)
	
	setup_sound_players()
	if not is_multiplayer_authority():
		$Head/Camera3D.current = false
	
	print("multiplayer authority " + str(get_multiplayer_authority()))
	
	if is_multiplayer_authority():
		camera.current = true
		print("Local player: camera enabled.")
	else:
		camera.current = false
		print("Remote player: camera disabled.")

func setup_sound_players():
	# Setup sprint sound player
	sprint_sound_player = AudioStreamPlayer.new()
	var sprint_sound = load("res://audio/player run.wav")
	if sprint_sound:
		sprint_sound_player.stream = sprint_sound
		sprint_sound_player.volume_db = -1.0
		sprint_sound_player.bus = "SFX"
		add_child(sprint_sound_player)
	else:
		print("Warning: Could not load sprint sound")
	
	# Setup drop item sound player - wrapped in try/catch to prevent level generation failure
	drop_item_sound_player = AudioStreamPlayer.new()
	
	# Use a deferred call to load the drop sound to avoid blocking level generation
	call_deferred("_load_drop_sound")
	
	# Setup flashlight toggle sound player
	flashlight_sound_player = AudioStreamPlayer.new()
	var flashlight_sound = load("res://audio/flashlight switch.wav")
	if flashlight_sound:
		flashlight_sound_player.stream = flashlight_sound
		flashlight_sound_player.volume_db = -3.0
		flashlight_sound_player.bus = "SFX"
		add_child(flashlight_sound_player)
	else:
		print("Warning: Could not load flashlight toggle sound")
		
	# Setup cash-in sound player
	cashin_sound_player = AudioStreamPlayer.new()
	var cashin_sound = load("res://audio/cashin sound.wav")
	if cashin_sound:
		cashin_sound_player.stream = cashin_sound
		cashin_sound_player.volume_db = -2.0
		cashin_sound_player.bus = "SFX"
		add_child(cashin_sound_player)
	else:
		print("Warning: Could not load cash-in sound")

func _load_drop_sound():
	# Try to load the drop sound file, but don't crash if it fails
	var drop_sound = null
	
	# Use FileAccess to check if the file exists first
	if FileAccess.file_exists("res://audio/dropitemsound.wav"):
		drop_sound = load("res://audio/dropitemsound.wav")
		
	if drop_sound:
		drop_item_sound_player.stream = drop_sound
		drop_item_sound_player.volume_db = -5.0
		drop_item_sound_player.bus = "SFX"
		add_child(drop_item_sound_player)
	else:
		print("Warning: Could not load drop item sound, but continuing anyway")
		# Create a dummy sound player to avoid null reference errors
		add_child(drop_item_sound_player)

func set_color(idx: int) -> void:
	#print("Materials: ", player_mesh.get_surface_override_material_count())
	#var material = player_mesh.get_surface_override_material(1)
	#material.albedo_color = player_colors[idx]
	#player_mesh.set_surface_override_material(1, material)
	var player_color = player_colors[idx % len(player_colors)]
	print("Color set to ", player_color)
	player_mesh.material_override.albedo_color = player_color

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if using_console:
		if event.is_action_pressed("Pause"):
			print("console toggled off")
			toggle_console()
			get_viewport().set_input_as_handled()
			
		if console_window:
			print("pushing input to console side")
			# Special handling for mouse wheel events - always forward them without marking as handled in player
			if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				console_window.get_parent().get_viewport().push_input(event)
				# Don't mark as handled here to let the event propagate to the console's _unhandled_input
			else:
				console_window.get_parent().get_viewport().push_input(event)
				get_viewport().set_input_as_handled()
		return  # Return here to prevent inventory scrolling while console is open
	else:
		if event.is_action_pressed("Use"):
			var current_item = inventory[current_slot]
			if current_item and current_item.type == "flashlight":
				MultiplayerRequest.request_flash_toggle(current_item.name)
				# Play flashlight toggle sound
				if flashlight_sound_player and is_multiplayer_authority():
					flashlight_sound_player.play()
		if event is InputEventMouseButton:
			if event.pressed:
				## Check if user scrolled up (4) or down (5)
				if event.button_index == 4:
					current_slot = (current_slot + 1) % inventory.size()
					MultiplayerRequest.update_current_slot.rpc_id(1, current_slot)
					var current_item = inventory[current_slot]
					MultiplayerRequest.changeHolding()
					if(current_item):
						emit_signal("inv_high", (current_slot - 1 + inventory.size()) % inventory.size(), current_slot, current_item.type)
					else:
						emit_signal("inv_high", (current_slot - 1 + inventory.size()) % inventory.size(), current_slot, "")
				elif event.button_index == 5:  # Scroll wheel down
					current_slot = (current_slot - 1 + inventory.size()) % inventory.size()
					MultiplayerRequest.update_current_slot.rpc_id(1, current_slot)
					var current_item = inventory[current_slot]
					MultiplayerRequest.changeHolding()
					if(current_item):
						emit_signal("inv_high", (current_slot + 1) % inventory.size(), current_slot, current_item.type)
					else:
						emit_signal("inv_high", (current_slot + 1) % inventory.size(), current_slot, "")
				if inventory[current_slot] == null:
					is_holding = false
				else:
					is_holding = true
#helper for console
func toggle_console() -> void:
	using_console = !using_console
	if using_console:
		console_window.visible = true
		console_window.input_bar.grab_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		#clear crt shader effect completely
		texture_rect.visible = false
		camera_locked = true
		MultiplayerRequest.changeHolding()

		print("shader disabled")
	else:
		console_window.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		texture_rect.visible = true
		update_health_indicator()
		camera_locked = false
		MultiplayerRequest.changeHolding()
		# Reset camera to follow head directly
		camera.global_transform = $Head.global_transform

func _physics_process(delta: float) -> void:
	if (dead): 
		return
	if not is_multiplayer_authority(): return
	if camera_locked and console_window:
		var console_root = console_window.get_parent().get_parent()
		var console_screen = console_root.get_node("CSGBox3D/MeshInstance3D")
		
		if console_screen:
			var target_transform = console_screen.global_transform
			# Position player 1m away from console screen
			var player_offset = target_transform.basis.z * 1.0
			global_transform.origin = target_transform.origin + player_offset
			
			# Face player towards console screen
			look_at(target_transform.origin, Vector3.UP)
			rotation.x = 0  # Keep player upright
			rotation.z = 0
			
			# Align camera with player's new rotation
			camera.global_transform = camera.global_transform.interpolate_with(
				Transform3D(global_transform.basis, global_transform.origin),
				delta * 5
			)
		return
	# Apply gravity if not on the floor
	if using_console:
		return
	if not is_on_floor():
		velocity += GRAVITY_FORCE * delta
	else:
		if is_jumping:
			animation_player.play("player_anim/jump_end")
			is_jumping = false

	# Handle jumping
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_FORCE
		animation_player.play("player_anim/jump_start")
		animation_player.speed_scale = 1.0
		is_jumping = true

	# Handle sprinting input
	if Input.is_action_pressed("Sprint"):
		if not is_running and current_stamina > STAMINA_THRESHOLD / 2:
			is_running = true
			if sound_emitter:
				sound_emitter._on_player_action("sprint")
		elif is_running and current_stamina > 0:
			movement_speed = RUN_SPEED
			current_stamina -= STAMINA_DRAIN_RATE * delta
		else:
			is_running = false
			movement_speed = WALK_SPEED
	else:
		is_running = false
		movement_speed = WALK_SPEED
		current_stamina += STAMINA_REGEN_RATE * delta

	# Get the interaction area
	var overlapping_bodies = interaction_area.get_overlapping_bodies()
	
	if overlapping_bodies.size() > 0:
		var closest_object = null
		var closest_distance = INF
		var camera_position = $Head/Camera3D.global_position
		
		for body in overlapping_bodies:
			var distance = camera_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_object = body
		
		if closest_object:
			var candidate = closest_object
			print(candidate)
			while candidate and not candidate.has_method("interact"):
				candidate = candidate.get_parent()
			
			if candidate and candidate.has_method("interact"):
				interact_label.visible = true
				if Input.is_action_just_pressed("Interact"):
					MultiplayerRequest.request_item_interact(candidate.name)
					# Check if this is a door and emit sound
					if candidate.is_in_group("doors") and sound_emitter:
						sound_emitter._on_player_action("door")
			else:
				if closest_object.is_in_group("console_collider") and near_console:
					interact_label.visible = true
					if Input.is_action_just_pressed("Interact"):
						toggle_console()
				else:
					interact_label.visible = false
	else:
		interact_label.visible = false
	
	if Input.is_action_just_pressed("Drop") and is_holding:
		MultiplayerRequest.request_item_drop()
		# Play drop item sound
		if drop_item_sound_player and is_multiplayer_authority():
			drop_item_sound_player.play()
			# Emit sound for earworm
			if sound_emitter:
				sound_emitter._on_player_action("drop")
	
	# Clamp stamina to valid range
	current_stamina = clamp(current_stamina, 0.0, 1.5)

	# Get input direction and calculate movement
	var input_vector: Vector2 = Input.get_vector("Left", "Right", "Forward", "Back")
	var move_direction: Vector3 = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * movement_speed
		velocity.z = move_direction.z * movement_speed
		# Play walk or run animation based on movement speed
		if is_running:
			animation_player.play("player_anim/walk")
			animation_player.speed_scale = 2.0
			
			# Handle sprint sound
			if is_multiplayer_authority() and sprint_sound_player:
				if not sprint_sound_player.playing:
					sprint_sound_player.play()
		else:
			animation_player.play("player_anim/walk")
			animation_player.speed_scale = 1.0
			
			# Stop sprint sound if it was playing
			if is_multiplayer_authority() and sprint_sound_player and sprint_sound_player.playing:
				sprint_sound_player.stop()
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta)
		velocity.z = move_toward(velocity.z, 0, movement_speed * delta)
		# Play idle animation when not moving
		if not is_jumping:
			animation_player.play("player_anim/idle")
			animation_player.speed_scale = 1.0
			
		# Stop sprint sound if it was playing
		if is_multiplayer_authority() and sprint_sound_player and sprint_sound_player.playing:
			sprint_sound_player.stop()

	# Update stamina bar value smoothly
	if stamina_bar:
		stamina_bar.value = lerp(stamina_bar.value, current_stamina - STAMINA_THRESHOLD / 2, 0.1)

	# Move the character
	move_and_slide()

func endGame() -> void:
	if(score >= quota):
		get_tree().change_scene_to_file("res://Scenes/win.tscn")
	else:
		return

func update_health_indicator():
	if crt_shader_material and crt_shader_material is ShaderMaterial:
		var health_ratio = float(current_health) / float(max_health)
		
		# Calculate parameter values using the min and max ranges
		var vignette_intensity = lerp(max_vignette_intensity, min_vignette_intensity, health_ratio)
		var noise_amount = lerp(min_noise_amount, max_noise_amount, 1.0 - health_ratio)
		var scan_line_amount = lerp(min_scan_line_amount, max_scan_line_amount, 1.0 - health_ratio)
		
		# Adjust shader parameters
		crt_shader_material.set("shader_param/vignette_intensity", vignette_intensity)
		crt_shader_material.set("shader_param/noise_amount", noise_amount)
		crt_shader_material.set("shader_param/scan_line_amount", scan_line_amount)

func take_damage(amount: int):
	# If player is invincible, ignore the damage
	if not is_multiplayer_authority():
		return

	if is_invincible:
		return
		
	print("Player took damage: ", amount)
	current_health -= amount
	
	# Flash effect
	if is_multiplayer_authority():
		var damage_tint = Color(1, 0, 0, 0.3)
		var tween = create_tween()
		crt_shader_material.set_shader_parameter("tint_color", damage_tint)
		tween.tween_property(crt_shader_material, "shader_parameter/tint_color", Color(0, 0, 0, 0), 0.3)
	
	# Start invincibility period
	is_invincible = true
	invincibility_timer.start()
	
	if current_health <= 0:
		current_health = 0
		MultiplayerRequest.request_player_dead();
	else:
		update_health_indicator()


func death_effect():
	animation_player.play("player_anim/die")

func end_invincibility() -> void:
	is_invincible = false
func _on_invincibility_timer_timeout():
	is_invincible = false

func apply_knockback(force: Vector3):
	velocity += force
	move_and_slide()

# Add a function to play the cash-in sound that can be called from cashBox.gd
func play_cashin_sound():
	if cashin_sound_player and is_multiplayer_authority():
		cashin_sound_player.play()
