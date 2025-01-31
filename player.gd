extends CharacterBody3D

# Constants
const WALK_SPEED = 3.0  # Default walking speed
const RUN_SPEED = 6.0  # Sprinting speed
const JUMP_FORCE = 4.5  # Force applied for jumping
const STAMINA_DRAIN_RATE = 0.01  # Rate at which stamina drains while sprinting
const STAMINA_REGEN_RATE = 0.5  # Rate at which stamina regenerates while not sprinting
const GRAVITY_FORCE = Vector3.DOWN * 9.8  # Gravity vector
const STAMINA_THRESHOLD = 0.5  # Buffer threshold for stamina management

signal value_changed(new_value)

# Variables
@export var stamina_bar: VSlider  # Reference to the stamina UI slider
@export var interaction_area: Area3D
@export var interact_label: Label
@export var texture_rect: TextureRect

@export var min_vignette_intensity: float = 0.0
@export var max_vignette_intensity: float = 1.0
@export var min_noise_amount: float = 0.03
@export var max_noise_amount: float = 0.13
@export var min_scan_line_amount: float = 0.5
@export var max_scan_line_amount: float = 1.0

@export var quota: int = 600

var current_stamina: float = 1.0 + STAMINA_THRESHOLD  # Current stamina level
var is_running: bool = false  # Whether the player is sprinting
var movement_speed: float = WALK_SPEED  # Current movement speed
var is_holding: bool = false # Whether the player is holding an intem
var current_health: float = 100.0
var max_health: float = 100.0
var crt_shader_material: ShaderMaterial
var inv_size: int = 0
var currIdx: int

var inventory := [null, null, null, null]
var current_slot := 0
var score: int = 0
var popup_scene = preload("res://Scenes/pop_up.tscn")

var is_invincible: bool = false
var invincibility_timer: Timer

func _ready():
	add_to_group("players")
	crt_shader_material = texture_rect.material
	var msg = "Collect a total of " + str(quota)
	var popup_instance = popup_scene.instantiate()
	popup_instance.popup_text = msg
	add_child(popup_instance)
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.wait_time = 0.2
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	add_child(invincibility_timer)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			## Check if user scrolled up (4) or down (5)
			if event.button_index == 4:
				current_slot = (current_slot + 1) % inventory.size()
				_update_equipped_item()
			elif event.button_index == 5:  # Scroll wheel down
				current_slot = (current_slot - 1 + inventory.size()) % inventory.size()
				_update_equipped_item()
			if inventory[currIdx] == null:
				is_holding = false
			else:
				is_holding = true
#
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
		item_socket.remove_child(old_item)
		var container = get_node("InventoryContainer")
		if container:
			container.add_child(old_item)  # Store the old item safely in the inventory container
		else:
			print("InventoryContainer not found. Old item may not be stored correctly.")
	if new_item:
		if new_item.get_parent():
			new_item.get_parent().remove_child(new_item)
		item_socket.add_child(new_item)
		new_item.transform = Transform3D()

func _physics_process(delta: float) -> void:
	# Apply gravity if not on the floor
	if not is_on_floor():
		velocity += GRAVITY_FORCE * delta

	# Handle jumping
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_FORCE

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
			while candidate and not candidate.has_method("interact"):
				candidate = candidate.get_parent()
			
			if candidate and candidate.has_method("interact"):
				interact_label.visible = true
				if Input.is_action_just_pressed("Interact") and candidate.is_in_group("doors"):
					candidate.interact(global_transform)
				elif Input.is_action_just_pressed("Interact") and candidate.is_in_group("cash"):
					var val = candidate.interact(self)
					inventory[current_slot] = null
					inv_size -= 1
					score += val
					print(score)
					var msg = "Scrap value " + str(val)
					var popup_instance = popup_scene.instantiate()
					popup_instance.popup_text = msg
					add_child(popup_instance)
					emit_signal("value_changed", val)
					endGame()
					inventory[current_slot] = null
				elif Input.is_action_just_pressed("Interact") and inv_size == 4:
					var item_socket = self.get_node("Head/ItemSocket")
					var curr_item = item_socket.get_child(0)
					curr_item.drop(self)
					var static_candidate = candidate.interact(self)
					inventory[current_slot] = static_candidate
				elif Input.is_action_just_pressed("Interact"):
					var static_candidate = candidate.interact(self)
					for i in range(inventory.size()):
						if inventory[i] == null:
							inventory[i] = static_candidate
							current_slot = i
							inv_size += 1
							## Move the item under a hidden "inventory_container" node so it stays in the scene tree but out of the world
							#var container = get_node("InventoryContainer")
							#if container:
								#container.add_child(static_candidate)
							break
					is_holding = true
			else:
				interact_label.visible = false
	else:
		interact_label.visible = false
	
	if Input.is_action_just_pressed("Drop") and is_holding:
		var item_socket = self.get_node("Head/ItemSocket")
		var curr_item = item_socket.get_child(0)
		print(curr_item.name)
		curr_item.drop(self)
		inventory[current_slot] = null
		inv_size -= 1
		is_holding = false
	
	# Clamp stamina to valid range
	current_stamina = clamp(current_stamina, 0.0, 1.5)

	# Get input direction and calculate movement
	var input_vector: Vector2 = Input.get_vector("Left", "Right", "Forward", "Back")
	var move_direction: Vector3 = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * movement_speed
		velocity.z = move_direction.z * movement_speed
	else:
		velocity.x = move_toward(velocity.x, 0, movement_speed * delta)
		velocity.z = move_toward(velocity.z, 0, movement_speed * delta)

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
	if is_invincible:
		return
		
	print("Player took damage: ", amount)
	current_health -= amount
	
	# Start invincibility period
	is_invincible = true
	invincibility_timer.start()
	
	if current_health <= 0:
		current_health = 0
		get_tree().change_scene_to_file("res://Scenes/Gameover.tscn")
	else:
		update_health_indicator()

func end_invincibility() -> void:
	is_invincible = false
func _on_invincibility_timer_timeout():
	is_invincible = false
