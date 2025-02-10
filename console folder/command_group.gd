@icon("res://console folder/icons/command group.png")
extends Node
class_name CommandGroup

func _ready():
	assert(name.find(" ") == -1) # No spaces
	name = name.to_lower() # Case-insensitive for simplicity
