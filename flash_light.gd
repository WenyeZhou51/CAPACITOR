extends Pickapable  # Inherits from base class

class_name Flashlight

@onready var light: SpotLight3D = $Model/FlashLight
@export var flashlight_sound: AudioStreamPlayer

# Keep existing light-specific logic from flash_light.gd lines 3-28
var light_strength: float = 1.5
var decay_rate: float = 0.1
var decay_interval: float = 20.0
var min_strength: float = 0.2
var decay_timer: float = 0.0

func _process(delta: float) -> void:
	decay_timer += delta
	if decay_timer >= decay_interval:
		decay_timer = 0.0
		light_strength = max(light_strength - decay_rate, min_strength)
		light.light_energy = light_strength

func use(player: Node) -> void:
	print("flash being used")
	light.visible = !light.visible
	flashlight_sound.play()
	
func turn_off():
	if light.visible:
		light.visible = false
		flashlight_sound.play()

func turn_on():
	if not light.visible:
		light.visible = false
		flashlight_sound.play()
