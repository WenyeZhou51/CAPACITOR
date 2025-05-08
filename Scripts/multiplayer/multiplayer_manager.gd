extends Node

signal host_msg
signal external_ip_obtained(ip_address: String)

# Load the IPEncoder class directly
const IPEncoderClass = preload("res://Scripts/Management/ip_encoder.gd")
var ip_encoder = IPEncoderClass.new()

##### GAME VARS AND LOGIC
var map_seed = 1

##### MULTIPLAYER VARS AND LOGIC
const SERVER_PORT = 8080
var SERVER_IP = "127.0.0.1"
const MAX_PLAYERS = 4
const CONNECTION_TIMEOUT = 15 # seconds

const DEBUG = true  # Toggle debug logging

var players = {}
var player_count = 1
var map: String
var player_username = "the nameless soul"
var player_info = {
	"id": 0,
	"username": ""
}

var upnp_enabled = true
var upnp: UPNP
var external_ip = ""
var is_connecting = false
var connection_timer: Timer
var network_status = "Not connected"

func debug_log(message: String) -> void:
	if DEBUG:
		print("[MultiplayerManager][%d] %s" % [Time.get_ticks_msec(), message])

func _ready():
	# Initialize connection timer
	connection_timer = Timer.new()
	connection_timer.one_shot = true
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)
	
	# Setup multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connection_timeout():
	if is_connecting:
		is_connecting = false
		host_msg.emit("Connection timed out")
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.close()

##### UPnP PORT FORWARDING #####

func setup_upnp() -> int:
	print("[DEBUG] setup_upnp() - Starting UPnP setup")
	debug_log("Setting up UPnP...")
	host_msg.emit("Setting up port forwarding...")
	
	upnp = UPNP.new()
	print("[DEBUG] setup_upnp() - Created new UPNP instance")
	var discover_result = upnp.discover()
	print("[DEBUG] setup_upnp() - UPnP discover result: " + str(discover_result))
	
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		print("[DEBUG] setup_upnp() - UPnP discovery failed")
		host_msg.emit("UPnP setup failed")
		debug_log("UPnP discovery failed with error: " + str(discover_result))
		return discover_result
	
	print("[DEBUG] setup_upnp() - UPnP discovery succeeded")
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		print("[DEBUG] setup_upnp() - Valid gateway found")
		# Try getting the external IP
		external_ip = upnp.query_external_address()
		print("[DEBUG] setup_upnp() - External IP query result: " + (external_ip if external_ip != "" else "empty"))
		
		if external_ip == "":
			print("[DEBUG] setup_upnp() - Failed to get external IP")
			host_msg.emit("Couldn't get external IP")
			debug_log("UPnP: Failed to get external IP")
		else:
			print("[DEBUG] setup_upnp() - Successfully got external IP: " + external_ip)
			debug_log("UPnP: External IP: " + external_ip)
			
		# Map the port
		print("[DEBUG] setup_upnp() - Attempting to map port " + str(SERVER_PORT))
		var port_mapping_result = upnp.add_port_mapping(SERVER_PORT, SERVER_PORT, "Godot Game", "UDP")
		print("[DEBUG] setup_upnp() - Port mapping result: " + str(port_mapping_result))
		
		if port_mapping_result != UPNP.UPNP_RESULT_SUCCESS:
			print("[DEBUG] setup_upnp() - Port mapping failed")
			host_msg.emit("Port forwarding failed")
			debug_log("UPnP: Port mapping failed with error: " + str(port_mapping_result))
			return port_mapping_result
			
		print("[DEBUG] setup_upnp() - Port mapping successful")
		debug_log("UPnP: Port mapping successful!")
		return UPNP.UPNP_RESULT_SUCCESS
	else:
		print("[DEBUG] setup_upnp() - Invalid gateway")
		host_msg.emit("UPnP gateway invalid")
		debug_log("UPnP: Invalid gateway")
		return UPNP.UPNP_RESULT_INVALID_GATEWAY

func remove_upnp_port_mapping():
	print("[DEBUG] remove_upnp_port_mapping() - Starting function")
	print("[DEBUG] remove_upnp_port_mapping() - upnp exists: " + str(upnp != null))
	
	if upnp and upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		print("[DEBUG] remove_upnp_port_mapping() - Valid gateway found, removing port mapping")
		var result = upnp.delete_port_mapping(SERVER_PORT, "UDP")
		print("[DEBUG] remove_upnp_port_mapping() - Result: " + str(result))
		
		if result == UPNP.UPNP_RESULT_SUCCESS:
			debug_log("UPnP port mapping removed successfully")
			print("[DEBUG] remove_upnp_port_mapping() - Port mapping removed successfully")
		else:
			debug_log("Failed to remove UPnP port mapping: " + str(result))
			print("[DEBUG] remove_upnp_port_mapping() - Failed to remove port mapping: " + str(result))
	else:
		print("[DEBUG] remove_upnp_port_mapping() - No valid gateway, nothing to remove")

##### HOSTING AND JOINING #####

func host_game():
	print("[DEBUG] host_game() - Starting host game function")
	print("[DEBUG] host_game() - multiplayer_peer exists: " + str(multiplayer.multiplayer_peer != null))
	
	if multiplayer.multiplayer_peer != null:
		print("[DEBUG] host_game() - Closing existing multiplayer peer")
		multiplayer.multiplayer_peer.close()
	else:
		print("[DEBUG] host_game() - No existing multiplayer peer to close")
	
	host_msg.emit("Hosting game...")
	debug_log("Starting host initialization")
	
	player_info.username = player_username
	print("[DEBUG] host_game() - Player username set to: " + player_username)
	
	# Try UPnP setup if enabled
	var upnp_result = UPNP.UPNP_RESULT_NO_DEVICES
	if upnp_enabled:
		print("[DEBUG] host_game() - Starting UPnP setup")
		upnp_result = setup_upnp()
		print("[DEBUG] host_game() - UPnP setup completed with result: " + str(upnp_result))
	
	var server_peer = ENetMultiplayerPeer.new()
	print("[DEBUG] host_game() - Created new ENetMultiplayerPeer")
	var error = server_peer.create_server(SERVER_PORT, MAX_PLAYERS)
	print("[DEBUG] host_game() - create_server result: " + str(error))
	
	if error != OK:
		debug_log("ERROR: Failed to create server: " + str(error))
		host_msg.emit("Failed to create server. Error code: " + str(error))
		
		# Clean up UPnP if we succeeded with that but failed to create server
		if upnp_result == UPNP.UPNP_RESULT_SUCCESS:
			print("[DEBUG] host_game() - Removing UPnP port mapping due to server creation failure")
			remove_upnp_port_mapping()
		return
		
	debug_log("Server created successfully on port " + str(SERVER_PORT))
	print("[DEBUG] host_game() - Setting multiplayer.multiplayer_peer")
	multiplayer.multiplayer_peer = server_peer
	
	player_info.id = 1
	players[1] = player_info.duplicate()
	print("[DEBUG] host_game() - Added host player to players dictionary with ID 1")
	
	# set map seed
	randomize()
	#map_seed = randi()
	map_seed = 1
	
	# Update network status
	network_status = "Hosting"
	print("[DEBUG] host_game() - Network status set to: " + network_status)
	
	# Share connection information
	if external_ip != "":
		print("[DEBUG] host_game() - External IP available: " + external_ip)
		
		# Encode the IP using Base36
		var encoded_ip = ip_encoder.encode_ip(external_ip)
		print("[DEBUG] host_game() - Encoded IP: " + encoded_ip)
		
		print("[DEBUG] host_game() - About to emit external_ip_obtained signal")
		# Emit signal with the encoded IP for the label
		external_ip_obtained.emit(encoded_ip)
		print("[DEBUG] host_game() - Signal external_ip_obtained emitted with: " + encoded_ip)
		host_msg.emit("Hosting successful!")
	else:
		print("[DEBUG] host_game() - No external IP available")
		external_ip_obtained.emit("No UPnP - Manual forwarding needed")
		host_msg.emit("UPnP failed. Manual port forwarding required.")
	
	print("[DEBUG] host_game() - Completed host_game function")

func kick_everyone():
	print("[DEBUG] kick_everyone() - Starting function")
	print("[DEBUG] kick_everyone() - is_server: " + str(multiplayer.is_server()))
	print("[DEBUG] kick_everyone() - has_multiplayer_peer: " + str(multiplayer.multiplayer_peer != null))
	
	if multiplayer.is_server() and multiplayer.multiplayer_peer:
		print("[DEBUG] kick_everyone() - Server with valid peer, kicking all clients")
		for idx in players.keys():
			if players[idx].id != 1:
				print("[DEBUG] kick_everyone() - Disconnecting peer: " + str(players[idx].id))
				multiplayer.multiplayer_peer.disconnect_peer(players[idx].id)
		# Then disconnect the host
		print("[DEBUG] kick_everyone() - Clearing players dictionary")
		players = {}
		print("[DEBUG] kick_everyone() - Setting multiplayer_peer to null")
		multiplayer.multiplayer_peer = null
		
		# Clean up UPnP port mapping
		if upnp_enabled:
			print("[DEBUG] kick_everyone() - Removing UPnP port mapping")
			remove_upnp_port_mapping()
		
		network_status = "Not connected"
		host_msg.emit("Disconnected from game")
	else:
		print("[DEBUG] kick_everyone() - Not a server or no multiplayer peer, nothing to kick")

func kick_client(client_id: int):
	print("[DEBUG] kick_client() - Starting function for client ID: " + str(client_id))
	print("[DEBUG] kick_client() - is_server: " + str(multiplayer.is_server()))
	print("[DEBUG] kick_client() - has_multiplayer_peer: " + str(multiplayer.multiplayer_peer != null))
	
	if multiplayer.is_server() and multiplayer.multiplayer_peer:
		debug_log("Kicking client " + str(client_id))
		if client_id == 1:
			print("[DEBUG] kick_client() - Kicking host (client ID 1)")
			var message = "The host has disconnected! Please rejoin a live session"
			# Send the message to each connected client
			for idx in players:
				#print("Checking players content", players[idx].id)
				if players[idx].id != 1:
					print("[DEBUG] kick_client() - Sending disconnect message to client: " + str(players[idx].id))
					rpc_id(players[idx].id, "display_session_end_message", message)
			
			# Clean up UPnP port mapping
			if upnp_enabled:
				print("[DEBUG] kick_client() - Removing UPnP port mapping")
				remove_upnp_port_mapping()
				
			print("[DEBUG] kick_client() - Setting multiplayer_peer to null")
			multiplayer.multiplayer_peer = null
			network_status = "Not connected"
		else:
			print("[DEBUG] kick_client() - Disconnecting client: " + str(client_id))
			multiplayer.multiplayer_peer.disconnect_peer(client_id)
	else:
		print("[DEBUG] kick_client() - Not a server or no multiplayer peer, can't kick client: " + str(client_id))

func join_game():
	debug_log("Starting client initialization")
	host_msg.emit("Connecting...")
	
	player_info.username = player_username
	
	# Check if the SERVER_IP is an encoded IP or a standard IP
	if ip_encoder.is_valid_encoded_ip(SERVER_IP):
		print("[DEBUG] join_game() - Detected encoded IP: " + SERVER_IP)
		# Decode the IP
		var decoded_ip = ip_encoder.decode_ip(SERVER_IP)
		print("[DEBUG] join_game() - Decoded to: " + decoded_ip)
		SERVER_IP = decoded_ip
	else:
		print("[DEBUG] join_game() - Using standard IP format: " + SERVER_IP)
	
	var client_peer = ENetMultiplayerPeer.new()
	
	# Configure the client for better network conditions
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	
	debug_log("Client created successfully, attempting connection to " + SERVER_IP)
	multiplayer.multiplayer_peer = client_peer
	
	# Start connection timeout timer
	is_connecting = true
	connection_timer.wait_time = CONNECTION_TIMEOUT
	connection_timer.start()
	
	network_status = "Connecting..."

func start_game():
	if !multiplayer.is_server():
		debug_log("Only the host can start the game")
		host_msg.emit("Only the host can start the game")
		return
		
	debug_log("Starting game with map seed: " + str(map_seed))
	begin_game_logic.rpc(map_seed)

func get_network_status() -> String:
	return network_status

##### CONNECTION CALLBACKS #####

func _on_connected_to_server():
	debug_log("Successfully connected to server!")
	is_connecting = false
	connection_timer.stop()
	network_status = "Connected"
	
	# Register ourselves with the server
	player_info.id = multiplayer.get_unique_id()
	register_player.rpc_id(1, player_info)
	
	# Show success message to the player
	host_msg.emit("Joined successfully as " + player_username)

func _on_connection_failed():
	debug_log("Connection to server failed")
	host_msg.emit("Connection failed")
	is_connecting = false
	connection_timer.stop()
	network_status = "Not connected"
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()

func _on_server_disconnected():
	debug_log("Disconnected from server")
	host_msg.emit("Disconnected from server")
	network_status = "Not connected"
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()

##### RPC FUNCTIONS #####

@rpc("any_peer")
func register_player(new_player_info):
	var sender_id = multiplayer.get_remote_sender_id()
	debug_log("Registering player: ID=" + str(sender_id) + ", Username=" + new_player_info.username)
	
	# Only allow registration if we're the server
	if !multiplayer.is_server():
		return
		
	# Store the player info
	new_player_info.id = sender_id
	players[sender_id] = new_player_info
	
	# Tell this new player about all existing players (including the server/host)
	for id in players:
		# Skip sending the player their own info
		if id != sender_id:
			# Tell this new player about existing player
			register_player.rpc_id(sender_id, players[id])
	
	# Update player count and inform all clients
	player_count = players.size()
	set_map_seed_and_player_count.rpc(map_seed, player_count)
	
	# Notify host about new player
	host_msg.emit("Player " + new_player_info.username + " joined!")

@rpc("any_peer", "call_local")
func switch_map(url: String):
	map = url

@rpc("any_peer", "call_local")
func begin_game_logic(seed: int):
	get_tree().change_scene_to_file(map)

func _on_peer_connected(id: int):
	debug_log("Peer connected with ID: " + str(id))
	
	if multiplayer.is_server():
		host_msg.emit("Client " + str(id) + " connected!")
	
@rpc("authority")
func set_map_seed_and_player_count(new: int, count: int):
	map_seed = new
	player_count = count
		
func _on_peer_disconnected(id: int):
	if (id == 1): 
		host_msg.emit("Host ended game session")
	
	if (!multiplayer.is_server()): 
		return
	
	debug_log("Peer disconnected with ID: " + str(id))
	host_msg.emit("Client " + str(id) + " has disconnected!")
	
	# Update player tracking
	if players.has(id):
		var username = players[id].username if players[id].has("username") else "Unknown"
		host_msg.emit("Player " + username + " (ID: " + str(id) + ") disconnected!")
		players.erase(id)
	
	player_count = players.size()
	set_map_seed_and_player_count.rpc(map_seed, player_count)
	removePlayerInGame.rpc(id)
	
@rpc("authority", "call_local")
func removePlayerInGame(id: int):
	var player = get_tree().get_root().get_node_or_null("Level/players/" + str(id))
	if (!player): return
	player.queue_free()
	
@rpc
func display_session_end_message(message: String):
	host_msg.emit(message)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Clean up on application exit
		if upnp_enabled and external_ip != "":
			remove_upnp_port_mapping()
