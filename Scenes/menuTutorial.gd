extends Control


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/testscene.tscn")

#func _on_options_pressed() -> void:
	#pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_multiplayer_pressed() -> void:
	MultiplayerManager.switch_map("res://Scenes/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")
	
	
#func _on_tutorial_pressed() -> void:
	#get_tree().change_scene_to_file("res://Scenes/MenuTutorial.tscn")


func _on_easy_pressed() -> void:
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_0/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_medium_pressed() -> void:
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_1/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_hard_pressed() -> void:
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_2/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")
