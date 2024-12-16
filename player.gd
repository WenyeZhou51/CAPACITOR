extends CharacterBody3D

# Constants
const WALK_SPEED = 1.0  # Default walking speed
const RUN_SPEED = 3.0  # Sprinting speed
const JUMP_FORCE = 4.5  # Force applied for jumping
const STAMINA_DRAIN_RATE = 0.3  # Rate at which stamina drains while sprinting
const STAMINA_REGEN_RATE = 0.5  # Rate at which stamina regenerates while not sprinting
const GRAVITY_FORCE = Vector3.DOWN * 9.8  # Gravity vector
const STAMINA_THRESHOLD = 0.5  # Buffer threshold for stamina management

# Variables
@export var stamina_bar: VSlider  # Reference to the stamina UI slider
var current_stamina: float = 1.0 + STAMINA_THRESHOLD  # Current stamina level
var is_running: bool = false  # Whether the player is sprinting
var movement_speed: float = WALK_SPEED  # Current movement speed

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
			is_running = true  # Start sprinting only if stamina is above the threshold
		elif is_running and current_stamina > 0:
			movement_speed = RUN_SPEED
			current_stamina -= STAMINA_DRAIN_RATE * delta
		else:
			is_running = false  # Stop sprinting when stamina depletes
			movement_speed = WALK_SPEED
	else:
		is_running = false
		movement_speed = WALK_SPEED
		current_stamina += STAMINA_REGEN_RATE * delta

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
