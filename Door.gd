extends Node3D

@export var open_angle_deg: float = 90.0      # How far the door opens in degrees
@export var open_duration: float = 0.1        # Duration of the open/close animation in seconds
@export var player_detection_range: float = 1.5

var is_open: bool = false
var original_rotation_y: float = 0.0
var target_angle_y: float = 0.0
var current_tween: Tween = null

func _ready():
	add_to_group("doors")
	# Store the original rotation around Y axis
	await get_tree().process_frame
	original_rotation_y = rotation.y
	target_angle_y = original_rotation_y
	
func interact(player: Player) -> void:
	if current_tween != null:
		# If the door is currently animating, ignore interactions until finished
		return
		
	$AudioStreamPlayer3D.play()
	EarwormManager.get_instance().emit_sound(global_position, 20.0)

	if is_open:
		# Door is open, so close it by rotating back to original rotation
		# Use a helper function to ensure shortest rotation path
		target_angle_y = shortest_angle(rotation.y, original_rotation_y)
		is_open = false
	else:
		# Door is closed, so open it away from the player
		var door_global_transform = global_transform
		var door_forward = door_global_transform.basis.z.normalized()
		var door_position = door_global_transform.origin
		var player_position = player.global_transform.origin
		var dir_to_player = (player_position - door_position).normalized()

		var dot = door_forward.dot(dir_to_player)
		var open_angle_rad = deg_to_rad(open_angle_deg)

		if dot > 0:
			target_angle_y = shortest_angle(rotation.y, original_rotation_y + open_angle_rad)
		else:
			target_angle_y = shortest_angle(rotation.y, original_rotation_y - open_angle_rad)

		is_open = true

	# Create a tween to animate the door rotation.
	current_tween = get_tree().create_tween()
	current_tween.tween_property(self, "rotation:y", target_angle_y, open_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.finished.connect(_on_tween_finished)

func _on_tween_finished():
	current_tween = null

# Helper function to find the shortest angle path from current to target
func shortest_angle(current: float, target: float) -> float:
	# Normalize difference to (-PI, PI)
	var difference = fmod(target - current, TAU)
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	# Apply the shortest path difference
	return current + difference
