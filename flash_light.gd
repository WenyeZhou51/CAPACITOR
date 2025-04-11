extends Pickapable  # Inherits from base class

class_name Flashlight_Class

@onready var light: SpotLight3D = $Model/FlashLight
@export var flashlight_sound: AudioStreamPlayer
@export var light_strength: float = 3.5

func _ready() -> void:
	light.light_energy = light_strength

@rpc("authority", "call_local")
func set_light_strength(strength: float):
	light_strength = strength
	light.light_energy = strength

# Keep existing light-specific logic from flash_light.gd lines 3-28
#var light_strength: float = 1.5
# EXPERIMENTAL VALUE FOR TESTS!!!
#var decay_rate: float = 1
#var decay_interval: float = 1
#var min_strength: float = 0.2
#var decay_timer: float = 0.0
#

#func _process(delta: float) -> void:
	#if is_multiplayer_authority():
		#decay_timer += delta
		#if decay_timer >= decay_interval:
			#decay_timer = 0.0
			#light_strength = max(light_strength - decay_rate, min_strength)
			#light.light_energy = light_strength
			#rpc("sync_energy", light_strength)
#
#@rpc("any_peer", "unreliable")
#func sync_energy(new_energy: float) -> void:
	## Only non-authority peers need to update from the sync.
	#if not is_multiplayer_authority():
		#light.light_energy = new_energy
#
#func use(player: Node) -> void:
	#print("flash being used")
	#light.visible = !light.visible
	#flashlight_sound.play()
	#
#func turn_off():
	#if light.visible:
		#light.visible = false
		#flashlight_sound.play()
#
#func turn_on():
	#if not light.visible:
		#light.visible = false
		#flashlight_sound.play()
