extends Control

var typed_label: Label
var full_text: String = ""
var current_text: String = ""
var char_index: int = 0
var typing_speed: float = 0.05
var typing_timer: Timer
var type_sound: AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Setup for typewriter effect
	typed_label = $TextureRect/"typed label"
	full_text = typed_label.text
	typed_label.text = ""
	
	# Create and configure the timer
	typing_timer = Timer.new()
	typing_timer.wait_time = typing_speed
	typing_timer.one_shot = false
	typing_timer.autostart = true
	add_child(typing_timer)
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	
	# Create and configure the sound player
	type_sound = AudioStreamPlayer.new()
	type_sound.stream = load("res://audio/flashlight.wav")
	type_sound.volume_db = -10.0  # Adjust volume as needed
	add_child(type_sound)

# Called when the timer times out
func _on_typing_timer_timeout() -> void:
	if char_index < full_text.length():
		# Add the next character
		current_text += full_text[char_index]
		typed_label.text = current_text
		char_index += 1
		
		# Play the sound
		type_sound.play()
	else:
		# Stop the timer when all text is displayed
		typing_timer.stop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
