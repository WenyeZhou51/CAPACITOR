extends Node

# Adjust these values to balance gameplay
@export var footstep_radius: float = 0.0  # Setting to 0 to disable footstep sounds
@export var sprint_radius: float = 10.0  # How far sprint sounds can be heard
@export var door_radius: float = 20.0  # How far door sounds can be heard
@export var drop_item_radius: float = 20.0  # How far item dropping sounds can be heard
@export var action_radius: float = 15.0  # How far other actions can be heard
@export var footstep_interval: float = 0.4  # Time between footstep sounds (seconds)
@export var sprint_interval: float = 0.1  # Time between sprint sounds (seconds)

# Internal variables
var player: CharacterBody3D
var footstep_timer: float = 0.0
var sprint_timer: float = 0.0
var previous_position: Vector3
var was_moving: bool = false
var is_sprinting: bool = false

func _ready() -> void:
	# Get parent if it's the player, otherwise find player in scene
	if get_parent() is CharacterBody3D:
		player = get_parent()
	else:
		await get_tree().process_frame
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0:
			player = players[0]
	
	if player:
		previous_position = player.global_position
		print("[SOUND EMITTER] Connected to player at position: ", previous_position)
		
		# Connect to player's signals if they exist
		if player.has_signal("sprint_started"):
			player.connect("sprint_started", _on_player_sprint_started)
		if player.has_signal("sprint_ended"):
			player.connect("sprint_ended", _on_player_sprint_ended)
	else:
		print("[SOUND EMITTER] WARNING: Could not find player!")

func _process(delta: float) -> void:
	if not player:
		return
		
	# Check if player is sprinting directly
	if player.has_method("is_sprinting"):
		is_sprinting = player.is_sprinting()
	elif "is_running" in player:
		is_sprinting = player.is_running
		
	# Detect movement for footsteps
	var current_position = player.global_position
	var movement = current_position.distance_to(previous_position)
	var is_moving = movement > 0.01  # Small threshold to detect actual movement
	
	# Only emit sprint sounds, no more footstep sounds during normal walking
	if is_moving and is_sprinting:
		sprint_timer += delta
		if sprint_timer >= sprint_interval:
			emit_sprint_sound()
			sprint_timer = 0.0
			
		# Emit additional sound when starting to sprint
		if not was_moving:
			emit_sprint_sound()
	else:
		sprint_timer = 0.0
	
	was_moving = is_moving
	previous_position = current_position

# Function to emit footstep sound - no longer used for normal walking
func emit_footstep_sound() -> void:
	if player and footstep_radius > 0.0:  # Only emit if radius is greater than 0
		print("[SOUND EMITTER] Emitting footstep sound at: ", player.global_position)
		EarwormManager.get_instance().emit_sound(player.global_position, footstep_radius)

# Function to emit sprint sound
func emit_sprint_sound() -> void:
	if player:
		print("[SOUND EMITTER] Emitting sprint sound at: ", player.global_position)
		if player.is_multiplayer_authority():
			# Send sound to server and all peers
			rpc("_emit_sound_networked", player.global_position, sprint_radius)

@rpc("any_peer", "call_local", "reliable")
func _emit_sound_networked(sound_position: Vector3, radius: float) -> void:
	EarwormManager.get_instance().emit_sound(sound_position, radius)

# Function for door usage sound
func emit_door_sound() -> void:
	if player and player.is_multiplayer_authority():
		rpc("_emit_sound_networked", player.global_position, door_radius)

# Function for drop item sound
func emit_drop_item_sound() -> void:
	if player and player.is_multiplayer_authority():
		rpc("_emit_sound_networked", player.global_position, drop_item_radius)

# Call this when player performs a loud action (shooting, using items, etc.)
func emit_action_sound() -> void:
	if player:
		print("[SOUND EMITTER] Emitting action sound at: ", player.global_position)
		EarwormManager.get_instance().emit_sound(player.global_position, action_radius)

# Connect this to player's input events
func _on_player_action(action_type: String) -> void:
	match action_type:
		"shoot", "jump":
			emit_action_sound()
		"door":
			emit_door_sound()
		"drop":
			emit_drop_item_sound()
		"sprint":
			emit_sprint_sound()
		"crouch":
			# Change player state but don't emit extra sounds
			pass

# Signal handlers for player state changes
func _on_player_sprint_started() -> void:
	emit_sprint_sound()

func _on_player_sprint_ended() -> void:
	# Optional: emit a specific sound when stopping sprint
	pass 
