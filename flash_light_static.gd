extends Drop  # Inherits from base class

class_name Flashlight_Static_Class

@onready var light: SpotLight3D = $Model/FlashLight
@export var flashlight_sound: AudioStreamPlayer
@export var light_strength: float

# Keep existing light-specific logic from flash_light.gd lines 3-28
var decay_rate: float = 0.1
var decay_interval: float = 20
var min_strength: float = 1
var decay_timer: float = 0.0

func _ready() -> void:
	#light_strength = 1.5
	print("initializing the process")
	light.add_to_group("flashlight")
	set_process(true)

func _process(delta: float) -> void:
	print("Processing light decay for flashlight")
	if is_multiplayer_authority() and light.visible:
		decay_timer += delta
		if decay_timer >= decay_interval:
			decay_timer = 0.0
			light_strength = max(light_strength - decay_rate, min_strength)
			light.light_energy = light_strength
			light.light_energy = light_strength
			rpc("sync_energy", light_strength)

@rpc("any_peer", "unreliable")
func sync_energy(new_energy: float) -> void:
	# Only non-authority peers need to update from the sync.
	if not is_multiplayer_authority():
		light.light_energy = new_energy
