extends Node

##### GAME VARS AND LOGIC
var map_seed = 1
var quota = 100
var team_score = 0

signal team_score_changed
signal end_game

func request_score_update(update_value: int):
	print_debug("score update request val: "+ str(update_value))
	update_team_score.rpc_id(1, update_value)

@rpc("any_peer", "call_local")
func update_team_score(update_value: int):
	if not multiplayer.is_server(): return
	print_debug("host recieved update score request")
	team_score += update_value
	set_team_score.rpc(team_score)

@rpc("authority", "call_local")
func set_team_score(score: int):
	print_debug("client " + str(multiplayer.get_unique_id()) + " got set new score from host")
	team_score = score
	if (team_score >= quota):
		get_tree().change_scene_to_file("res://Scenes/win.tscn")
		return
	team_score_changed.emit(team_score)

##### MULTIPLAYER VARS AND LOGIC
const SERVER_PORT = 8080
var SERVER_IP = "127.0.0.1"

const DEBUG = true  # Toggle debug logging

var players = {}

var player_info = {
	"id": 0
}

func debug_log(message: String) -> void:
	if DEBUG:
		print("[MultiplayerManager][%d] %s" % [Time.get_ticks_msec(), message])
func host_game():
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
	
@rpc("any_peer", "call_local")
func begin_game_logic(seed: int):
	get_tree().change_scene_to_file("res://Scenes/testscene.tscn")

func _on_peer_connected(id: int):
	debug_log("Peer connected with ID: " + str(id))
	# Server creates peer
	if multiplayer.is_server():
		var this_player_info = {
			"id": id
		}
		players[id] = this_player_info
	set_map_seed.rpc_id(id, map_seed)
	
@rpc("authority")
func set_map_seed(new: int):
	map_seed = new
		
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
