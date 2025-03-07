extends Control

@onready var audio_player = $Click  # Reference the AudioStreamPlayer

func _on_start_pressed() -> void:
	audio_player.play()
	get_tree().change_scene_to_file("res://Scenes/testscene.tscn")

#func _on_options_pressed() -> void:
	#pass # Replace with function body.


func _on_quit_pressed() -> void:
	audio_player.play()
	get_tree().quit()


func _on_multiplayer_pressed() -> void:
	audio_player.play()
	MultiplayerManager.switch_map("res://Scenes/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")
	
	
func _on_tutorial_pressed() -> void:
	audio_player.play()
	get_tree().change_scene_to_file("res://Scenes/tutorial_menu/MenuTutorial.tscn")
