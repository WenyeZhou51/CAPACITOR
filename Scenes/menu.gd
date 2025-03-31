extends Control

@onready var click_good = $ClickGood # Reference the AudioStreamPlayer
@onready var click_back = $ClickBack # Reference the AudioStreamPlayer

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/innerMenus/GameMenu.tscn")

func _on_options_pressed() -> void:
	click_good.play()
	get_tree().change_scene_to_file("res://Scenes/OptionsMenu.tscn")


func _on_quit_pressed() -> void:
	click_back.play()
	get_tree().quit()


func _on_multiplayer_pressed() -> void:
	click_good.play()
	get_tree().change_scene_to_file("res://Scenes/innerMenus/GameMenu.tscn")
	
	
func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/tutorial_menu/MenuTutorial.tscn")
