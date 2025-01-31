extends SpotLight3D

# Variables for light strength and decay
var light_strength: float = 1.5
var decay_rate: float = 0.1
var decay_interval: float = 20.0
var min_strength: float = 0.2

# Timer to control decay intervals
var decay_timer: float = 0.0

func _ready() -> void:
	# Initialize the light's strength
	light_energy = light_strength

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Toggle visibility with input
	if Input.is_action_just_pressed("Light"):
		visible = !visible
	
	# Handle light strength decay
	decay_timer += delta
	if decay_timer >= decay_interval:
		decay_timer = 0.0  # Reset timer
		light_strength = max(light_strength - decay_rate, min_strength)  # Decay but clamp to minimum
		light_energy = light_strength  # Update the light's energy
