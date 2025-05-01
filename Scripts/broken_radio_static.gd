class_name BrokenRadioStatic extends Drop

var audio_player: AudioStreamPlayer3D
var noise_timer: Timer

# Timer for emitting noise to earworm
const NOISE_INTERVAL: float = 1.0  # Emit noise every second
const NOISE_RADIUS: float = 15.0   # Radius of noise detection

func _ready() -> void:
	# Set the price
	Price = 500
	
	# Set the type
	type = "brokenradio"
	
	# Create the audio player if it doesn't exist
	if !has_node("RadioAudio"):
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "RadioAudio"
		add_child(audio_player)
		
		# Load the radio sound
		var sound = load("res://audio/radio scrap sound new.wav")
		if sound:
			audio_player.stream = sound
			print("Radio sound loaded successfully")
			# Start playing the sound
			audio_player.play()
		else:
			print("Failed to load radio sound")
	else:
		audio_player = get_node("RadioAudio")
		# Start playing the sound
		if audio_player.stream:
			audio_player.play()
	
	# Create and start the noise timer
	noise_timer = Timer.new()
	noise_timer.wait_time = NOISE_INTERVAL
	noise_timer.one_shot = false
	noise_timer.timeout.connect(_on_noise_timer_timeout)
	add_child(noise_timer)
	noise_timer.start()

# Called when the noise timer times out
func _on_noise_timer_timeout() -> void:
	if audio_player.playing:
		# Emit sound for earworm to hear
		emit_radio_noise()

# Function to emit radio noise for earworm detection
func emit_radio_noise() -> void:
	# Use RPC call for multiplayer like other game objects
	if is_multiplayer_authority():
		rpc("_emit_sound_networked", global_position, NOISE_RADIUS)

@rpc("any_peer", "call_local", "reliable")
func _emit_sound_networked(sound_position: Vector3, radius: float) -> void:
	# Get the EarwormManager and emit sound at our position
	var manager = EarwormManager.get_instance()
	if manager:
		print("[BROKEN RADIO STATIC] Emitting radio noise at: ", sound_position)
		manager.emit_sound(sound_position, radius)

func _exit_tree() -> void:
	# Stop the timer when this node is removed from the scene
	if noise_timer and is_instance_valid(noise_timer):
		noise_timer.stop()

func drop(player: CharacterBody3D, drop_position: Vector3 = Vector3.ZERO, drop_direction: Vector3 = Vector3.FORWARD) -> void:
	# Stop audio and timer before dropping
	if audio_player and audio_player.playing:
		audio_player.stop()
	if noise_timer and noise_timer.is_stopped() == false:
		noise_timer.stop()
		
	# Call the parent drop function
	super.drop(player, drop_position, drop_direction) 
