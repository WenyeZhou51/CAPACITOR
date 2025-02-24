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

func _ready():
	set_multiplayer_authority(str(name).to_int())
	add_to_group("players")
	stamina_bar = get_node("/root/Level/UI/SprintSlider")
	interact_label = get_node("/root/Level/UI/InteractLabel")
	texture_rect = get_node("/root/Level/UI/TextureRect")
	crt_shader_material = texture_rect.material
	var msg = "Collect a total of " + str(GameState.get_quota())
	popup_instance = popup_scene.instantiate()
	popup_instance.popup_text = msg
	add_child(popup_instance)
	popup_instance.pop_up()
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.wait_time = 0.2
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	add_child(invincibility_timer)
	
	print("multiplayer authority " + str(get_multiplayer_authority()))
	
	if is_multiplayer_authority():
		camera.current = true
		print("Local player: camera enabled.")
	else:
		camera.current = false
		print("Remote player: camera disabled.")
		

func set_color(idx: int) -> void:
	print("Materials: ", player_mesh.get_surface_override_material_count())
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
			console_window.get_parent().get_viewport().push_input(event)
		get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed("Use"):
			var current_item = inventory[current_slot]
			print(current_item)
			if current_item and current_item.type == "flash":
				MultiplayerRequest.request_flash_toggle(current_item.name)
		if event is InputEventMouseButton:
			if event.pressed:
				## Check if user scrolled up (4) or down (5)
				if event.button_index == 4:
					current_slot = (current_slot + 1) % inventory.size()
					var current_item = inventory[current_slot]
					_update_equipped_item()
					if(current_item):
						emit_signal("inv_high", (current_slot - 1 + inventory.size()) % inventory.size(), current_slot, current_item.type)
					else:
						emit_signal("inv_high", (current_slot - 1 + inventory.size()) % inventory.size(), current_slot, "")
				elif event.button_index == 5:  # Scroll wheel down
					current_slot = (current_slot - 1 + inventory.size()) % inventory.size()
					var current_item = inventory[current_slot]
					_update_equipped_item()
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
		_update_equipped_item()

		print("shader disabled")
	else:
		console_window.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		texture_rect.visible = true
		update_health_indicator()
		camera_locked = false
		_update_equipped_item()
		# Reset camera to follow head directly
		camera.global_transform = $Head.global_transform

func _update_equipped_item() -> void:
	"""
	Equip (visually attach) whatever item is in `current_slot`, 
	and unequip any previously equipped item.
	"""
	var item_socket = get_node("Head/ItemSocket")
	var old_item = null
	if(item_socket.get_child_count() > 0):
		old_item = item_socket.get_child(0)
	var new_item = inventory[current_slot]
	if old_item:
		if(old_item.type == "flash"):
			var light_node = old_item.get_node("Model/FlashLight")
			if light_node and light_node is Light3D:
				light_node.visible = false
		item_socket.remove_child(old_item)
		var container = get_node("InventoryContainer")
		if container:
			container.add_child(old_item)  # Store the old item safely in the inventory container
		else:
			print("InventoryContainer not found. Old item may not be stored correctly.")
	if new_item:
		if new_item.get_parent():
			new_item.get_parent().remove_child(new_item)
		if(new_item.type == "flash"):
			var light_node = new_item.get_node("Model/FlashLight")
			if light_node and light_node is Light3D:
				light_node.visible = true
		item_socket.add_child(new_item)
		new_item.transform = Transform3D()

func _physics_process(delta: float) -> void:
	if (dead): return
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
			# TODO: add a sound effect here
			animation_player.play("player_anim/jump_end")
			EarwormManager.emit_sound(global_position)
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
		else:
			animation_player.play("player_anim/walk")
			animation_player.speed_scale = 1.0
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta)
		velocity.z = move_toward(velocity.z, 0, movement_speed * delta)
		# Play idle animation when not moving
		if not is_jumping:
			animation_player.play("player_anim/idle")
			animation_player.speed_scale = 1.0

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
	if (name != str(multiplayer.get_unique_id())):
		return
	if (dead): return
	dead = true
	# If player is invincible, ignore the damage
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
