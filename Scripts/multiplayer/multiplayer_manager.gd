extends Node

signal host_msg

##### GAME VARS AND LOGIC
var map_seed = 1

##### MULTIPLAYER VARS AND LOGIC
const SERVER_PORT = 8080
var SERVER_IP = "127.0.0.1"

const DEBUG = true  # Toggle debug logging

var players = {}
var player_count = 1
var map: String

var player_info = {
	"id": 0
}

func debug_log(message: String) -> void:
	if DEBUG:
		print("[MultiplayerManager][%d] %s" % [Time.get_ticks_msec(), message])

func host_game():
	host_msg.emit("Hosting game...")
	debug_log("Starting host initialization")
	var server_peer = ENetMultiplayerPeer.new()
	var error = server_peer.create_server(SERVER_PORT, 4)  # Max 4 players
	
	if error != OK:
		debug_log("ERROR: Failed to create server: " + str(error))
		return
		
	debug_log("Server created successfully on port " + str(SERVER_PORT))
	multiplayer.multiplayer_peer = server_peer
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	player_info.id = 1
	players[1] = player_info
	
	# set map seed
	randomize()
	map_seed = randi()
	
	host_msg.emit("Success! Share IP for others to join")
	
func join_game():
	debug_log("Starting client initialization")
	var client_peer = ENetMultiplayerPeer.new()
	var error = client_peer.create_client(SERVER_IP, SERVER_PORT)
	
	if error != OK:
		debug_log("ERROR: Failed to create client: " + str(error))
		return
		
	debug_log("Client created successfully, attempting connection to " + SERVER_IP)
	multiplayer.multiplayer_peer = client_peer

func start_game():
	begin_game_logic.rpc(0)

func switch_map(url: String):
	map = url

@rpc("any_peer", "call_local")
func begin_game_logic(seed: int):
	get_tree().change_scene_to_file(map)

func _on_peer_connected(id: int):
	debug_log("Peer connected with ID: " + str(id))
	# Server creates peer
	if multiplayer.is_server():
		var this_player_info = {
			"id": id
		}
		players[id] = this_player_info
	player_count += 1;
	set_map_seed_and_player_count.rpc(map_seed, player_count)
	if multiplayer.is_server():
		host_msg.emit("Client " + str(id) + " joined successfully!")
	
@rpc("authority")
func set_map_seed_and_player_count(new: int, count: int):
	map_seed = new
	player_count = count;
		
func _on_peer_disconnected(id: int):
	debug_log("Peer disconnected with ID: " + str(id))
	# host should delete player

#func _process(_delta: float):
	#if DEBUG and get_tree().get_multiplayer().has_multiplayer_peer():
		#var peer = get_tree().get_multiplayer().multiplayer_peer
		#if peer is ENetMultiplayerPeer:
			#debug_log(
				#"Network Status - Connected Peers: " + str(peer.get_connection_status()) +
				#" | Host: " + str(get_tree().get_multiplayer().is_server()) +
				#" | Unique ID: " + str(get_tree().get_multiplayer().get_unique_id())
			#)
