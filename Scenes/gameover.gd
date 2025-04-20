extends Control

@onready var click_good = $ClickGood
@onready var quota_label = $TextureRect/Label
@onready var time_label = $TextureRect/Label2
@onready var players_label = $TextureRect/Label3
@onready var win_sound = $WinSound
@onready var menu_item_sound = $WinMenuItemSound

# Animation parameters
var quota_value = 0
var target_quota = 0
var time_value = 0.0
var target_time = 0.0
var players_value = 0
var target_players = 0
var max_players = 0

# Animation control
var quota_done = false
var time_done = false
var players_done = false
var animation_started = false

# Animation speeds
var quota_speed = 20  # Quota per second
var time_speed = 15.0  # Seconds per second
var players_speed = 1  # Players per second

# Delay between animations
var delay_timer = 0.0
var delay_duration = 0.8

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Get the relevant game stats
	target_quota = GameState.get_quota()
	
	# Get the time from game state and make sure it's not zero
	target_time = GameState.get_game_time()
	print("Win screen - Retrieved game time: ", target_time)
	
	# Ensure we have a reasonable time to display
	if target_time <= 0.1:
		print("Warning: Game time was too low, using fallback value")
		target_time = 30.0  # Fallback time if game timer didn't work
	
	# Play win sound
	if win_sound:
		win_sound.play()
	
	# Initialize the labels
	quota_label.text = "Quota Reached: "
	
	# Hide the time and players labels initially - they'll appear in sequence
	time_label.visible = false
	players_label.visible = false
	
	# Start animations with slight delay
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(_start_animations)
	timer.start()
	
	print("Win screen setup complete. Quota: ", target_quota, 
		  " Time: ", target_time)
		  #" Players: ", target_players, "/", max_players)

func _start_animations() -> void:
	animation_started = true

func _process(delta: float) -> void:
	if not animation_started:
		return
	max_players = MultiplayerManager.player_count
	target_players = GameState.alive_count
	# Animate quota counter
	if not quota_done:
		quota_value += quota_speed * delta
		if quota_value >= target_quota:
			quota_value = target_quota
			quota_done = true
			delay_timer = 0.0  # Reset delay timer
			# Play sound effect
			if menu_item_sound:
				menu_item_sound.play()
		quota_label.text = "Quota Reached: " + str(int(quota_value))
	
	# Delay between animations
	elif quota_done and not time_label.visible:
		delay_timer += delta
		if delay_timer >= delay_duration:
			time_label.visible = true  # Show time label when it's time for its animation
			# Play menu item sound when time label appears
			if menu_item_sound:
				menu_item_sound.play()
	
	# Animate time counter (only start after quota is done AND delay has passed)
	elif quota_done and time_label.visible and not time_done:
		time_value += time_speed * delta
		if time_value >= target_time:
			time_value = target_time
			time_done = true
			delay_timer = 0.0  # Reset delay timer
			# Play sound effect
			if menu_item_sound:
				menu_item_sound.play()
		
		# Format time as MM:SS
		var minutes = int(time_value) / 60
		var seconds = int(time_value) % 60
		var time_str = "%02d:%02d" % [minutes, seconds]
		time_label.text = "Time Taken: " + time_str
	
	# Delay between time and players
	elif time_done and not players_label.visible:
		delay_timer += delta
		if delay_timer >= delay_duration:
			players_label.visible = true  # Show players label when it's time for its animation
			# Play menu item sound when players label appears
			if menu_item_sound:
				menu_item_sound.play()
	
	# Animate players counter (only start after time is done AND delay has passed)
	elif time_done and players_label.visible and not players_done:
		players_value += players_speed * delta
		if players_value >= target_players:
			players_value = target_players
			players_done = true
			# Play sound effect
			if menu_item_sound:
				menu_item_sound.play()
		# Get player stats
		
		players_label.text = "Players survived: " + str(int(players_value)) + "/" + str(max_players)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
