extends CharacterBody3D

class_name Player

# Constants
const WALK_SPEED = 4  # Default walking speed
const RUN_SPEED = 9.0  # Sprinting speed
const JUMP_FORCE = 6.5  # Force applied for jumping
const STAMINA_DRAIN_RATE = 0.01  #should be 0.21. for debug 0.01 Rate at which stamina drains while sprinting
const STAMINA_REGEN_RATE = 0.2  # Rate at which stamina regenerates while not sprinting
const GRAVITY_FORCE = Vector3.DOWN * 9.8 * 2  # Gravity vector
const STAMINA_THRESHOLD = 0.5  # Buffer threshold for stamina management

signal value_changed(new_value)
signal change_ui(idx, type)
signal inv_high(prev_idx: int, curr_idx: int, name: String)
var curSlotUpdating = false
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
@export var current_health: float = 10.0 #### MUST HAVE EXPORT FOR SYNCING

var tempLabel: Label
var healthLabel: Label
var staminaLabel: Label
var tempProgress: TextureProgressBar
var healthProgress: TextureProgressBar
var staminaProgress: TextureProgressBar

var current_stamina: float = 1.0 + STAMINA_THRESHOLD  # Current stamina level
var is_running: bool = false  # Whether the player is sprinting
var movement_speed: float = WALK_SPEED  # Current movement speed
var is_holding: bool = false # Whether the player is holding an intem
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
var spec_id = "1";
@onready var camera: Camera3D = $Head/Camera3D

# Sound players
var sprint_sound_player: AudioStreamPlayer
var drop_item_sound_player: AudioStreamPlayer
var flashlight_sound_player: AudioStreamPlayer
var cashin_sound_player: AudioStreamPlayer
var was_running: bool = false # Track previous running state

var sound_emitter: Node

var in_console_mode: bool = false
var has_typed_help: bool = false
var has_bought_coolant: bool = false
var has_picked_up_coolant: bool = false
var has_refueled_generator: bool = false

# At the class level, add a variable to store the label reference
var player_name_label: Label = null

# Store original CRT shader parameters to reset later
var default_crt_parameters = {}

signal console_toggled(is_using)

func _ready():
	set_multiplayer_authority(str(name).to_int())
	add_to_group("players")
	add_to_group("player")  # Add to player group for tutorial detection
	
	#/root/Level/UI/VBoxContainer/
	#const containers = ["TempDisplay", "HealthDisplay", "StaminaDisplay", "PowerDisplay"]
	
	# Status indicators
	healthLabel = get_node("/root/Level/UI/HealthDisplay/Label")
	staminaLabel = get_node("/root/Level/UI/StaminaDisplay/Label")
	healthProgress = get_node("/root/Level/UI/HealthDisplay/TextureProgressBar")
	staminaProgress = get_node("/root/Level/UI/StaminaDisplay/TextureProgressBar")
	
	interact_label = get_node("/root/Level/UI/InteractLabel")
	texture_rect = get_node("/root/Level/UI/TextureRect")
	crt_shader_material = texture_rect.material
	
	# Store default CRT parameters for resetting later
	if crt_shader_material and crt_shader_material is ShaderMaterial:
		_store_default_crt_parameters()
	
	# Listen for scene change signals to reset effects
	get_tree().root.connect("ready", _on_scene_changed)
	
	# Determine which tutorial level we're in and set the appropriate message
	var current_scene = get_tree().current_scene.scene_file_path
	var msg = ""
	
	if "tutorial_level_0" in current_scene:
		msg = "Collect and cash in 600 scrap"
	elif "tutorial_level_1" in current_scene:
		msg = "Beware the enemies"
	elif "tutorial_level_2" in current_scene:
		msg = "Gather and explore"
	else:
		msg = "Collect a total scrap value of: " + str(GameState.get_quota())
	
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
		$spatial/SubViewport/name.text = MultiplayerManager.player_username
	else:
		camera.current = false
		print("Remote player: camera disabled.")
	spec_id = str(multiplayer.get_unique_id());

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
	if not client_is_this_player(): return
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
				if(get_viewport()):
					get_viewport().set_input_as_handled()
		return  # Return here to prevent inventory scrolling while console is open
	else:
		if event.is_action_pressed("Use"):
			var current_item = inventory[current_slot]
			print("[Spray debug] Use action pressed, current item: " + str(current_item))
			if current_item:
				print("[Spray debug] Item type: " + str(current_item.type))
				
			if current_item and current_item.type == "flashlight":
				MultiplayerRequest.request_flash_toggle(current_item.name)
				# Play flashlight toggle sound
				if flashlight_sound_player and is_multiplayer_authority():
					flashlight_sound_player.play()
			elif current_item and current_item.type == "spraypaint":
				# Use the spray paint item
				print("[Spray debug] Found spraypaint item, checking for use method...")
				if current_item.has_method("use"):
					print("[Spray debug] Calling use() method on spraypaint")
					current_item.use(self)
				else:
					print("[Spray debug] ERROR: spraypaint has no use() method!")
					print("[Spray debug] Available methods: " + str(current_item.get_method_list()))
		if event is InputEventMouseButton:
			if event.pressed:
				check_inv_slot_change(event)
				
func check_inv_slot_change(event: InputEventMouseButton):
	if curSlotUpdating: return
	## Check if user scrolled up (4) or down (5)
	if event.button_index == 4:
		current_slot = (current_slot + 1) % inventory.size()
		curSlotUpdating = true
		set_inv_slot(current_slot)
		MultiplayerRequest.request_inventory_idx_change(current_slot)
		
	elif event.button_index == 5:  # Scroll wheel down
		current_slot = (current_slot - 1 + inventory.size()) % inventory.size()
		curSlotUpdating = true
		set_inv_slot(current_slot)
		MultiplayerRequest.request_inventory_idx_change(current_slot)
		
		
	
#helper for console
func toggle_console() -> void:
	using_console = !using_console
	# Update in_console_mode for tutorial tracking
	in_console_mode = using_console
	
	emit_signal("console_toggled", using_console)
	
	if using_console:
		console_window.visible = true
		console_window.input_bar.grab_focus()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		#clear crt shader effect completely
		texture_rect.visible = false
		camera_locked = true
		print("shader disabled")
	else:
		console_window.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		texture_rect.visible = true
		update_health_indicator()
		camera_locked = false

		# Reset camera to follow head directly
		camera.global_transform = $Head.global_transform

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if (dead): 
		# Animate the CRT effects for spectator mode
		_animate_spectator_effects(delta)
		
		if (Input.is_action_just_pressed("Jump")):
			var cur_spec = GameState.get_player_node_by_name((spec_id));
			var par = cur_spec.get_parent();
			var next_spec_idx = (cur_spec.get_index() + 1) % par.get_child_count();
			var next_spec = par.get_child(next_spec_idx)
			spec_id = next_spec.name
			next_spec.camera.current = true;
			
			# Update the player name label when switching players
			if player_name_label:
				var player_name = next_spec.name
				
				# Try to get username if available
				if next_spec.has_node("spatial/SubViewport/name"):
					var nametag = next_spec.get_node("spatial/SubViewport/name")
					if nametag and nametag.text and nametag.text.length() > 0:
						player_name = nametag.text
						
				player_name_label.text = "VIEWING: " + player_name
				print("Updated player name label to: " + player_name)
		return
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
			
			if ( not sprint_sound_player.playing):
				play_sound(Constants.SOUNDS.SPRINT)
				MultiplayerPropogate.propogate_player_play_sound.rpc(Constants.SOUNDS.SPRINT)
		else:
			animation_player.play("player_anim/walk")
			animation_player.speed_scale = 1.0
			
			# Stop sprint sound if it was playing
			if is_multiplayer_authority() and sprint_sound_player and sprint_sound_player.playing:
				sprint_sound_player.stop()
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * 1000)
		velocity.z = move_toward(velocity.z, 0, movement_speed * 1000)
		# Play idle animation when not moving
		if not is_jumping:
			animation_player.play("player_anim/idle")
			animation_player.speed_scale = 1.0
			
		# Stop sprint sound if it was playing
		if (sprint_sound_player.playing):
			stop_sound(Constants.SOUNDS.SPRINT)
			MultiplayerPropogate.propogate_player_stop_sound.rpc(Constants.SOUNDS.SPRINT)

	# Normalize stamina for display (0.0 to 1.0 scale)
	var stamina_ratio = clamp((current_stamina - STAMINA_THRESHOLD / 2) / (1.5 - STAMINA_THRESHOLD / 2), 0.0, 1.0)

	# Update stamina progress bar
	if staminaProgress:
		staminaProgress.value = stamina_ratio * 100

	# Update stamina label
	if staminaLabel:
		staminaLabel.text = "STAMINA\n" + str(round(stamina_ratio * 100)) + "%"
#
#
	## Update stamina bar value smoothly
	#if staminaProgress:
		#staminaProgress.value = lerp(staminaProgress.value, current_stamina - STAMINA_THRESHOLD / 2, 0.1)
	#else:
		#print("[UI] AAAAAAAAAAAAAAAAAAAAAA")
	#if staminaLabel:
		#
		#staminaLabel.text = "STAMINA\n" + str(floor(current_stamina / 1.5)) + "%"
	#else:
		#print("[UI] AAAAAAhealthAAAAAAAAAAAAAAAA")
	
	#if stamina_bar:
		#stamina_bar.value = lerp(stamina_bar.value, current_stamina - STAMINA_THRESHOLD / 2, 0.1)

	# Move the cSPRINTharacter
	move_and_slide()

func endGame() -> void:
	# Reset CRT effects before changing scene
	reset_crt_effects()
	
	if(score >= quota):
		get_tree().change_scene_to_file("res://Scenes/win.tscn")
	else:
		return

func stop_sound(sound: Constants.SOUNDS):
	match sound:
		Constants.SOUNDS.SPRINT:
			sprint_sound_player.stop()

func play_sound(sound: Constants.SOUNDS):
	match sound:
		Constants.SOUNDS.SPRINT: 
			if ! sprint_sound_player.playing:
				sprint_sound_player.play()
		Constants.SOUNDS.JUMP: 
			pass
		Constants.SOUNDS.DROP: 
			pass
		Constants.SOUNDS.DOOR: 
			pass
		Constants.SOUNDS.CASH_IN: 
			cashin_sound_player.play()

		

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
		
		# Update health progress bar
		if healthProgress:
			healthProgress.value = health_ratio * 100.0

		# Update stamina label
		if healthLabel:
			healthLabel.text = "HEALTH\n" + str(round(health_ratio * 100)) + "%"

func init_take_damage(amount: int):
	if not multiplayer.is_server(): return
	if dead: return
	if is_invincible:
		return
		
	print("Player took damage: ", amount)
	var new_health = current_health - amount
	
	MultiplayerPropogate.propogate_new_player_health.rpc(name, new_health)
	
	# Start invincibility period
	is_invincible = true
	invincibility_timer.start()
		
func set_health(new: int):
	var hurt = new < current_health
	current_health = new
	
	if (current_health <= 0):
		set_death(true)
	
	if hurt && is_multiplayer_authority():
		damage_taken_effect()
		update_health_indicator()
	
func set_death(new: bool):
	dead = new
	if (multiplayer.is_server()):
		GameState.reduce_alive_count(0)
	if (not is_multiplayer_authority()): return;
	if(dead):
		death_effect()
		var uis = get_tree().get_root().get_node_or_null("Level/UI/ninepatch")
		uis.visible = false
		print("player.gd: Died, dropping all items")
		var item_socket = get_node("Head/ItemSocket")
		var inventory_container = get_node("InventoryContainer")
		for i in range(4):
			MultiplayerRequest.request_inventory_idx_change(i)
			MultiplayerRequest.request_item_drop()
		return

func damage_taken_effect():
	var damage_tint = Color(1, 0, 0, 0.05)
	var tween = create_tween()
	crt_shader_material.set_shader_parameter("tint_color", damage_tint)
	tween.tween_property(crt_shader_material, "shader_parameter/tint_color", Color(0, 0, 0, 0), 0.3)

func death_effect():
	animation_player.play("player_anim/die")
	
	# Apply more severe CRT effect for spectator mode
	if crt_shader_material and crt_shader_material is ShaderMaterial:
		# IMPORTANT: Completely disable grille effect to prevent checkerboard pattern
		crt_shader_material.set_shader_parameter("grille_amount", 0.0)
		
		# Use much lower aberration to prevent color bleeding at edges
		crt_shader_material.set_shader_parameter("aberation_amount", 0.2)
		
		# Apply a very subtle red tint that won't affect the borders
		crt_shader_material.set_shader_parameter("tint_color", Color(0.7, 0.0, 0.0, 0.05))
		
		# Other effects that don't cause border issues
		crt_shader_material.set_shader_parameter("warp_amount", 4.0)
		crt_shader_material.set_shader_parameter("noise_amount", 0.2)
		crt_shader_material.set_shader_parameter("scan_line_amount", 1.0)
		crt_shader_material.set_shader_parameter("interference_amount", 0.4)
		crt_shader_material.set_shader_parameter("roll_line_amount", 0.7)
		
		# Use extreme vignette settings for pure black borders
		crt_shader_material.set_shader_parameter("vignette_amount", 2.0)
		crt_shader_material.set_shader_parameter("vignette_intensity", 1.5)
		
		# Create a label for the spectator mode instructions
		var space_label = Label.new()
		space_label.name = "SpectatorInstructions"
		space_label.text = "SPACE TO CYCLE VIEW"
		
		# Set proper anchors to center the label on screen
		space_label.anchor_left = 0.5
		space_label.anchor_top = 0.5
		space_label.anchor_right = 0.5
		space_label.anchor_bottom = 0.5
		
		# Set alignment for text within the label
		space_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		space_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Use bold red text for visibility
		var font_color = Color(1, 0, 0, 1)
		space_label.set("theme_override_colors/font_color", font_color)
		space_label.set("theme_override_font_sizes/font_size", 70)
		
		# Set the size and offset (larger size for the bigger font)
		space_label.size = Vector2(800, 200)
		# Offset from center position (half the width and height)
		space_label.position = Vector2(-400, -100)
		
		# Add to UI - using same parent as the spectator instructions
		add_child(space_label)
		
		# Create a tween to fade out the label
		var tween = create_tween()
		tween.tween_property(space_label, "modulate", Color(1, 0, 0, 0), 5.0)
		tween.tween_callback(space_label.queue_free)
		
		# PLAYER NAME LABEL - USING IDENTICAL SETUP LOGIC AS SPACE LABEL
		var name_label = Label.new()
		name_label.name = "PlayerNameLabel"
		
		# Get current spectated player name
		var current_player = GameState.get_player_node_by_name(spec_id)
		var player_name = current_player.name if current_player else "Unknown"
		
		# Try to get username from the player if possible
		if current_player and current_player.has_node("spatial/SubViewport/name"):
			var nametag = current_player.get_node("spatial/SubViewport/name")
			if nametag and nametag.text and nametag.text.length() > 0:
				player_name = nametag.text
				
		name_label.text = "VIEWING: " + player_name
		
		# USE IDENTICAL SETUP AS SPACE LABEL, just different position
		name_label.anchor_left = 0.5
		name_label.anchor_top = 0.5  # Center anchor, same as space label
		name_label.anchor_right = 0.5
		name_label.anchor_bottom = 0.5
		
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Green color
		name_label.set("theme_override_colors/font_color", Color(0, 1, 0, 1))
		name_label.set("theme_override_font_sizes/font_size", 70) # Same size as space label
		
		# Same size as space label
		name_label.size = Vector2(800, 200)
		# Position at bottom of screen (only difference is Y position)
		name_label.position = Vector2(-400, 200)  # Lower on screen than space label
		
		print("Creating player name label: " + name_label.text)
		add_child(name_label)
		
		# Store reference to update later when cycling players
		player_name_label = name_label

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

func client_is_this_player() -> bool:
	return name == str(multiplayer.get_unique_id())

# Add these at the top of Player class
var debug_item_locations = {}

func _set_item_visibility(item: Node, visible: bool, context: String = "") -> void:
	if not item: return
	var mesh_instance = item.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.visible = visible
		print("Setting {item.name} visibility to {visible} ({context})")
	if item.type == "flashlight":
		var light_node = item.get_node("Model/FlashLight")
		if light_node and light_node is Light3D:
			light_node.visible = visible

# Updated set_inv_slot
func set_inv_slot(new: int):
	current_slot = new
	var current_item = inventory[current_slot]
	
	print("Setting slot to {new}, item: {current_item.name if current_item else 'null'}")
	
	var pre = -1
	if current_item:
		is_holding = true
		emit_signal("inv_high", pre, current_slot, current_item.type)
	else:
		is_holding = false
		emit_signal("inv_high", pre, current_slot, "")
	
	var item_socket = get_node("Head/ItemSocket")
	var inventory_container = get_node("InventoryContainer")
	
	# Clear socket first
	while item_socket.get_child_count() > 0:
		var old_item = item_socket.get_child(0)
		item_socket.remove_child(old_item)
		_set_item_visibility(old_item, false, "moving to inventory")
		if inventory_container:
			inventory_container.add_child(old_item)
		else:
			print("Warning: No InventoryContainer found")
			old_item.queue_free()  # Prevent orphaned nodes
	
	if current_item:
		if current_item.get_parent():
			current_item.get_parent().remove_child(current_item)
		item_socket.add_child(current_item)
		current_item.transform = Transform3D()
		_set_item_visibility(current_item, true, "active in socket")
	
	curSlotUpdating = false

# Animate the CRT effects when in spectator mode
func _animate_spectator_effects(delta: float) -> void:
	if crt_shader_material and crt_shader_material is ShaderMaterial:
		# Ensure grille effect stays disabled to prevent checkerboard pattern
		crt_shader_material.set_shader_parameter("grille_amount", 0.0)
		
		# Only animate parameters that don't affect the borders
		var pulse = (sin(Time.get_ticks_msec() * 0.001) + 1.0) * 0.5
		
		# Keep aberration low to prevent color bleeding at edges
		crt_shader_material.set_shader_parameter("aberation_amount", 0.2)
		
		# Subtle noise animation
		var noise_amount = lerp(0.15, 0.25, pulse)
		crt_shader_material.set_shader_parameter("noise_amount", noise_amount)
		
		# Very subtle tint pulsing that won't affect borders
		var tint_alpha = lerp(0.03, 0.07, pulse)
		var tint_color = Color(0.7, 0.0, 0.0, tint_alpha)
		crt_shader_material.set_shader_parameter("tint_color", tint_color)
		
		# Changing roll speed
		var roll_speed = lerp(2.0, 4.0, pulse)
		crt_shader_material.set_shader_parameter("roll_speed", roll_speed)
		
		# Keep vignette settings high for pure black borders
		crt_shader_material.set_shader_parameter("vignette_amount", 2.0)
		crt_shader_material.set_shader_parameter("vignette_intensity", 1.5)

# Store original CRT shader parameters to reset later
func _store_default_crt_parameters():
	if crt_shader_material:
		default_crt_parameters = {
			"grille_amount": crt_shader_material.get_shader_parameter("grille_amount"),
			"aberation_amount": crt_shader_material.get_shader_parameter("aberation_amount"), 
			"tint_color": crt_shader_material.get_shader_parameter("tint_color"),
			"warp_amount": crt_shader_material.get_shader_parameter("warp_amount"),
			"noise_amount": crt_shader_material.get_shader_parameter("noise_amount"),
			"scan_line_amount": crt_shader_material.get_shader_parameter("scan_line_amount"),
			"interference_amount": crt_shader_material.get_shader_parameter("interference_amount"),
			"roll_line_amount": crt_shader_material.get_shader_parameter("roll_line_amount"),
			"vignette_amount": crt_shader_material.get_shader_parameter("vignette_amount"),
			"vignette_intensity": crt_shader_material.get_shader_parameter("vignette_intensity")
		}

# Reset CRT shader to default parameters
func reset_crt_effects():
	if crt_shader_material and default_crt_parameters.size() > 0:
		for param in default_crt_parameters:
			crt_shader_material.set_shader_parameter(param, default_crt_parameters[param])
		print("Reset CRT shader to default parameters")

# Called when scene changes (like going to menu or win screen)
func _on_scene_changed():
	# Reset effects when scene changes
	reset_crt_effects()
	print("Scene changed, reset CRT effects")

# Make sure we reset CRT effects when exiting gameplay
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# Object is being deleted, reset CRT effects
		reset_crt_effects()
		print("Player being deleted, reset CRT effects")

# Add a cleanup method to be called from external scripts like menu transitions
func cleanup_spectator_effects():
	# Clear any spectator-specific effects
	if player_name_label:
		player_name_label.queue_free()
		player_name_label = null
	
	# Reset CRT shader effects
	reset_crt_effects()
	
	print("Cleaned up spectator effects")
