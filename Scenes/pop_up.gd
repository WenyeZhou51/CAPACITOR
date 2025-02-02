extends Control

@export var display_time: float = 2.0  # Duration the text stays on screen
@export var popup_text: String = "Default Text"  # Text to display in the popup
@onready var label: Label = $Label  # Reference to the Label node

func _ready():
	# Set the text of the label
	label.text = popup_text
	
	# Start fading out after the display_time
	await get_tree().create_timer(display_time).timeout
	fade_out()

func fade_out():
	var tween = get_tree().create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(self.queue_free)  # Call `queue_free` directly after the fade-out
