extends Control

@onready var click_good = $ClickGood # Reference the AudioStreamPlayer
@onready var click_back = $ClickBack # Reference the AudioStreamPlayer

func _on_random_pressed() -> void:
	click_good.play()
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/win.tscn")
	MultiplayerManager.switch_map("res://Scenes/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_fixed_pressed() -> void:
	click_good.play()
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/tutorial_level_0/level_0_complete.tscn")
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_0/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")
	
func _on_demo_pressed() -> void:
	click_good.play()
	GameState.set_quota(600)
	GameState.set_end_scene("res://Scenes/tutorial_level_3/level_0_complete.tscn")
	MultiplayerManager.switch_map("res://Scenes/tutorial_level_3/testscene.tscn")
	get_tree().change_scene_to_file("res://Scenes/multiplayer/multiplayer_menu.tscn")


func _on_back_pressed() -> void:
	click_back.play()
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

# Connect description panel visibility to button hover events
func _ready() -> void:
	# The menu_button.gd script handles the scaling effects automatically,
	# but we still need to manually connect our description panel visibility
	$MarginContainer/TextureRect/VBoxContainer/Random.mouse_entered.connect(_on_random_mouse_entered)
	$MarginContainer/TextureRect/VBoxContainer/Random.mouse_exited.connect(_on_random_mouse_exited)
	$MarginContainer/TextureRect/VBoxContainer/Fixed.mouse_entered.connect(_on_fixed_mouse_entered)
	$MarginContainer/TextureRect/VBoxContainer/Fixed.mouse_exited.connect(_on_fixed_mouse_exited)
	$MarginContainer/TextureRect/VBoxContainer/Demo.mouse_entered.connect(_on_fixed_mouse_entered)
	$MarginContainer/TextureRect/VBoxContainer/Demo.mouse_exited.connect(_on_fixed_mouse_exited)

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
