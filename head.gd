extends Node3D

const sensitivity = 0.005
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event : InputEvent) -> void:
	var player = get_parent()
	if (player.name != str(multiplayer.get_unique_id())): return
	if player.dead : return
	if player.camera_locked:
		return
	if event is InputEventMouseMotion:
		get_parent().rotate_y(-event.relative.x * sensitivity)
		rotate_x(-event.relative.y*sensitivity)
		rotation.x = clamp(rotation.x,deg_to_rad(-80),deg_to_rad(90))
