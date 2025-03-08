extends Control



func _on_random_pressed() -> void:
	GameState.set_quota(1000)
	GameState.set_end_scene("res://Scenes/win.tscn")
	MultiplayerManager.switch_map("res://Scenes/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_fixed_pressed() -> void:
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/tutorial_level_0/level_0_complete.tscn")
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_0/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

# Show the Random button description when mouse hovers over it
func _on_random_mouse_entered() -> void:
	$MarginContainer/TextureRect/RandomDescription.visible = true

# Hide the Random button description when mouse leaves
func _on_random_mouse_exited() -> void:
	$MarginContainer/TextureRect/RandomDescription.visible = false

# Show the Fixed button description when mouse hovers over it
func _on_fixed_mouse_entered() -> void:
	$MarginContainer/TextureRect/FixedDescription.visible = true

# Hide the Fixed button description when mouse leaves
func _on_fixed_mouse_exited() -> void:
	$MarginContainer/TextureRect/FixedDescription.visible = false
