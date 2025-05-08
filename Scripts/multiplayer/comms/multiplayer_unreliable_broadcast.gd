extends Node

# This script handles high-frequency unreliable updates like player movement
# Using unreliable RPCs for position and rotation updates reduces bandwidth
# and prevents network congestion when playing over the internet

# Constant for update frequency (times per second)
const UPDATE_FREQUENCY = 20  # Adjust based on your game's needs
var update_timer: Timer
var last_positions = {}
var last_rotations = {}
var last_head_rotations = {}

# Threshold for position updates (in units)
const POSITION_THRESHOLD = 0.05
# Threshold for rotation updates (in radians)
const ROTATION_THRESHOLD = 0.05

func _ready():
	# Initialize the update timer
	update_timer = Timer.new()
	update_timer.wait_time = 1.0 / UPDATE_FREQUENCY
	update_timer.autostart = true
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)

func _on_update_timer_timeout():
	if not multiplayer.has_multiplayer_peer():
		return
		
	# If we're the host or a client, broadcast our own position
	if multiplayer.has_multiplayer_peer():
		var player = GameState.get_player_node_by_name(str(multiplayer.get_unique_id()))
		if player:
			broadcast_player_transform(player)

# Called by each client to broadcast their own position
func broadcast_player_transform(player: Node3D):
	var player_id = multiplayer.get_unique_id()
	
	# Only send updates if we're connected and the player is valid
	if not player or not multiplayer.has_multiplayer_peer():
		return
		
	# Get current transforms
	var position = player.global_position
	var rotation = player.global_rotation
	var head_rotation = Vector3.ZERO
	
	if player.has_node("Head"):
		head_rotation = player.get_node("Head").rotation
	
	# Check if changes are significant enough to send
	var should_update = false
	
	if not last_positions.has(player_id) or position.distance_to(last_positions[player_id]) > POSITION_THRESHOLD:
		should_update = true
		
	if not last_rotations.has(player_id) or rotation.distance_to(last_rotations[player_id]) > ROTATION_THRESHOLD:
		should_update = true
		
	if not last_head_rotations.has(player_id) or head_rotation.distance_to(last_head_rotations[player_id]) > ROTATION_THRESHOLD:
		should_update = true
	
	# Only send if there's a significant change
	if should_update:
		# Save last sent values
		last_positions[player_id] = position
		last_rotations[player_id] = rotation
		last_head_rotations[player_id] = head_rotation
		
		# Send to all players (including server)
		_update_player_transform.rpc(position, rotation, head_rotation)

# Receive transform updates from other players
@rpc("any_peer", "unreliable")
func _update_player_transform(position: Vector3, rotation: Vector3, head_rotation: Vector3):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Don't process our own updates
	if sender_id == multiplayer.get_unique_id():
		return
		
	# Find the player node
	var player = GameState.get_player_node_by_name(str(sender_id))
	if not player:
		return
	
	# Apply position with interpolation
	_apply_position_update(player, position)
	
	# Apply rotation with interpolation
	_apply_rotation_update(player, rotation)
	
	# Update head rotation if it exists
	if player.has_node("Head"):
		_apply_head_rotation_update(player.get_node("Head"), head_rotation)

# Helper functions for smooth interpolation

func _apply_position_update(player: Node3D, new_position: Vector3):
	# For smooth movement, we'll interpolate towards the target
	# This can be called from _process if needed for even smoother movement
	player.global_position = player.global_position.lerp(new_position, 0.5)

func _apply_rotation_update(player: Node3D, new_rotation: Vector3):
	player.global_rotation = player.global_rotation.lerp(new_rotation, 0.5)

func _apply_head_rotation_update(head_node: Node3D, new_rotation: Vector3):
	head_node.rotation = head_node.rotation.lerp(new_rotation, 0.5)

# Process interpolation on each frame for smoother movement
func _process(_delta):
	if not multiplayer.has_multiplayer_peer():
		return
		
	# Apply smoother interpolation for all remote players
	for player_id in MultiplayerManager.players.keys():
		if player_id != multiplayer.get_unique_id():
			var player = GameState.get_player_node_by_name(str(player_id))
			if player and last_positions.has(player_id):
				# Continue smoothly interpolating between updates
				player.global_position = player.global_position.lerp(last_positions[player_id], 0.2)
				
				if last_rotations.has(player_id):
					player.global_rotation = player.global_rotation.lerp(last_rotations[player_id], 0.2)
				
				if player.has_node("Head") and last_head_rotations.has(player_id):
					player.get_node("Head").rotation = player.get_node("Head").rotation.lerp(last_head_rotations[player_id], 0.2)
