class_name BrokenRadio extends Pickapable

var audio_player: AudioStreamPlayer3D
var noise_timer: Timer

# Timer for emitting noise to earworm
const NOISE_INTERVAL: float = 1.0  # Emit noise every second
const NOISE_RADIUS: float = 30.0   # Radius of noise detection

func _ready() -> void:
	# Call the parent _ready function to add to scrap group
	super()
	
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
		else:
			print("Failed to load radio sound")
	else:
		audio_player = get_node("RadioAudio")
		
	# Create and start the noise timer
	noise_timer = Timer.new()
	noise_timer.wait_time = NOISE_INTERVAL
	noise_timer.one_shot = false
	noise_timer.timeout.connect(_on_noise_timer_timeout)
	add_child(noise_timer)
	noise_timer.stop()  # Initially stopped until radio is activated

func interact(player: Player) -> void:
	# Start playing the sound when picked up
	if audio_player and audio_player.stream:
		audio_player.play()
		print("Playing radio sound")
		
		# Start the noise timer when the radio is picked up
		if noise_timer:
			noise_timer.start()
	
	# Call the parent interact function to handle pickup
	super.interact(player)

# Called when the noise timer times out
func _on_noise_timer_timeout() -> void:
	if audio_player.playing:
		# Emit sound for earworm to hear using the same pattern as other game objects
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
		print("[BROKEN RADIO] Emitting radio noise at: ", sound_position)
		manager.emit_sound(sound_position, radius)

# Create a static version for inventory
func convert_rigidbody_to_staticbody(rigidbody: RigidBody3D) -> StaticBody3D:
	# Stop any audio and timer before converting
	if audio_player and audio_player.playing:
		audio_player.stop()
	if noise_timer and noise_timer.is_stopped() == false:
		noise_timer.stop()
	
	# Create the static version using parent method
	var static_body = super.convert_rigidbody_to_staticbody(rigidbody)
	
	# Add script to handle the radio functionality when static
	var radio_static_script = load("res://Scripts/broken_radio_static.gd")
	if radio_static_script:
		static_body.set_script(radio_static_script)
		print("Adding broken radio static script to object")
	
	return static_body 
