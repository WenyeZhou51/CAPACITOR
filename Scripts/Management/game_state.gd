extends Node

var _quota = 400
var _team_score = 0
var alive_count = 0
var auto_start = false  # Flag to indicate if the game should auto-start

# Time tracking variables
var _game_time = 0.0
var _timer_running = false
var _start_time = 0
var total_elapsed_time = 0.0  # Store the final elapsed time

var endScene: String = "res://Scenes/win.tscn"

var players = {}

signal team_score_changed
signal end_game
signal change_ui
signal inv_high

func _ready():
	# Instead of connecting to scene ready, we'll directly initialize the timer
	# for the current scene
	call_deferred("_check_and_start_timer")

func _check_and_start_timer():
	# This is called after _ready to ensure the scene is fully loaded
	var current_scene = get_tree().current_scene
	if current_scene:
		print("Current scene: ", current_scene.name)
		# Start timer for game levels
		if current_scene.name == "testscene" or "level" in current_scene.name.to_lower():
			print("Game level detected - starting timer")
			_start_timer()

func _start_timer():
	# Reset and start the timer
	_game_time = 0.0
	_start_time = Time.get_ticks_msec()
	_timer_running = true
	total_elapsed_time = 0.0
	print("Game timer started at: ", _start_time)

func initNewLevel(quota: int):
	_quota = quota
	_team_score = 0
	alive_count = MultiplayerManager.player_count
	
	# Start the timer when a new level is initiated
	_start_timer()

func get_quota() -> int:
	return _quota
	
func set_quota(val: int) -> void:
	_quota = val
	
func get_team_score() -> int:
	return _team_score

func set_team_score(val: int) -> void:
	_team_score = val
	team_score_changed.emit(_team_score)
	check_game_end()

func set_end_scene(scene: String) -> void:
	endScene = scene
	
func set_auto_start(value: bool) -> void:
	auto_start = value
	
func should_auto_start() -> bool:
	return auto_start

# Calculate current game time
func calculate_current_time() -> float:
	var current_time_ms = Time.get_ticks_msec()
	
	# Only care about timer running for debug output, still calculate if _start_time exists
	if _start_time > 0:
		var elapsed_ms = current_time_ms - _start_time
		
		# Debug information
		print("Current time ms: ", current_time_ms)
		print("Start time ms: ", _start_time)
		print("Elapsed ms: ", elapsed_ms)
		
		# Handle potential issues with time calculation
		if elapsed_ms < 0:
			print("ERROR: Negative elapsed time detected!")
			return 1.0  # Return a small positive value
			
		var seconds = elapsed_ms / 1000.0
		print("Calculated seconds: ", seconds)
		return max(seconds, 1.0)  # Ensure at least 1 second
	else:
		print("Start time is invalid or not set")
		return 1.0

# Stop the timer and record the final time
func stop_timer() -> float:
	if not _timer_running:
		print("stop_timer called but timer was not running")
		return total_elapsed_time
		
	# CRITICAL FIX: Calculate the time BEFORE setting _timer_running to false
	var elapsed_time = calculate_current_time()
	
	# Now it's safe to stop the timer
	_timer_running = false
	
	# Make sure we have at least a minimum reasonable time
	total_elapsed_time = max(elapsed_time, 1.0)
	print("Timer stopped - Final time: ", total_elapsed_time)
	return total_elapsed_time

# Get the game time (either current running time or final recorded time)
func get_game_time() -> float:
	if _timer_running and _start_time > 0:
		var current_time = calculate_current_time()
		print("Current running time: ", current_time)
		return current_time
	else:
		print("Returning recorded time: ", total_elapsed_time)
		# Ensure we return at least 1 second to avoid fallback
		return max(total_elapsed_time, 1.0)

func _process(delta: float) -> void:
	if _timer_running and _start_time > 0:
		# Periodically debug the timer
		if Engine.get_process_frames() % 180 == 0:  # About every 3 seconds at 60 FPS
			var current_time = calculate_current_time()
			print("Game running for: ", current_time, " seconds")

func check_game_end() -> void:
	if (_team_score >= _quota):
		print("Quota reached! Stopping timer and recording final time...")
		# Stop the timer when quota is reached
		stop_timer()
		print("Game ended with quota reached! Time: ", total_elapsed_time)
		
		# Change to the win scene
		get_tree().change_scene_to_file(endScene)
	elif alive_count <= 0:
		# Stop the timer when all players are dead
		stop_timer()
		print("Game over - all players dead. Time: ", total_elapsed_time)
		
		get_tree().change_scene_to_file("res://Scenes/Gameover.tscn")

@rpc("any_peer")
func reduce_alive_count(state: int) -> void:
	if (state == 0):
		reduce_alive_count.rpc(1)
	alive_count -= 1
	check_game_end()
	
func get_player_node_by_name(name: String) -> Player:
	return get_tree().get_root().get_node_or_null("Level/players/" + name)

func instant_win() -> void:
	# Stop the timer when using instant win
	stop_timer()
	print("Instant win! Time: ", total_elapsed_time)
	
	get_tree().change_scene_to_file(endScene)
