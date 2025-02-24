extends Node

signal sound_made(position: Vector3, radius: float)

var _instance = null
static func get_instance() -> Node:
	return Engine.get_main_loop().get_root().get_node("/root/EarwormManager")

# Called when a sound occurs in the game world
#func emit_sound(position: Vector3, intensity: float):
	#emit_signal("sound_made", position, intensity)

func emit_sound(position: Vector3, radius: float):
	emit_signal("sound_made", position, radius)
