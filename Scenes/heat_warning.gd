extends Control

@export var visual_warning: Control
@export var audio_player: AudioStreamPlayer

func warn_player() -> void:
	audio_player.playing = true
	visual_warning.visible = true
	
	await get_tree().create_timer(3.5).timeout
	
	visual_warning.visible = false
