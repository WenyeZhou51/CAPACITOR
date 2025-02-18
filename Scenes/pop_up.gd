extends Control

@export var display_time: float = 2.0  # Duration the text stays on screen
@export var popup_text: String = "Default Text"  # Text to display in the popup



func pop_up():
	var label = get_node("Label")
	label.text = popup_text
	label.modulate = Color(1, 1, 1, 1)
	# Start fading out after the display_time
	if(get_tree()):
		await get_tree().create_timer(display_time).timeout
		fade_out(label)

func fade_out(label: Label):
	var tween = get_tree().create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 1.0)
