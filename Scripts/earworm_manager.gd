extends Node

signal sound_made(position: Vector3, radius: float)

# EarwormManager is already registered as an autoload in project.godot
# This method provides a clean way to access the singleton
static func get_instance() -> Node:
	if Engine.get_main_loop():
		return Engine.get_main_loop().get_root().get_node_or_null("/root/EarwormManager")
	return null

# Called when the game starts
func _ready():
	print("[EARWORM MANAGER] Initialized")

# Called when a sound occurs in the game world
#func emit_sound(position: Vector3, intensity: float):
	#emit_signal("sound_made", position, intensity)

func emit_sound(position: Vector3, radius: float):
	print("[EARWORM MANAGER] Sound emitted at: ", position, " with radius: ", radius)
	emit_signal("sound_made", position, radius)
