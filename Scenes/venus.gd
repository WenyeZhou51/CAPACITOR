extends Node3D

# Declare variables for the AnimationPlayer
var animation_player: AnimationPlayer

func _ready():
	# Get the AnimationPlayer node
	animation_player = $VenusSKin/AnimationPlayer  
	# Play the "walk" animation
	if animation_player.has_animation("Walking"):
		animation_player.play("Walking")
	else:
		print("Error: 'Walking' animation not found!")
