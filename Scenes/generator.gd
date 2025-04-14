extends StaticBody3D

@export var sub_viewport: SubViewport
@export var heat_bar: ProgressBar
@export var energy_bar: ProgressBar

var heat_needle: ColorRect
var heat_label: Label
var power_needle: ColorRect
var power_label: Label

const NEEDLE_MIN_DEG = -60.0
const NEEDLE_MAX_DEG = 60.0

@onready var electricity_manager = get_node("/root/Level/Electricity Manager")
@onready var world_environment = get_node("/root/Level/WorldEnvironment")

@export var heat_level: float = 0.0
@export var heat_increase_rate: float = 1.0  # Heat units increased per second
@export var max_heat: float = 100.0

var time_accumulator: float = 0.0
const HEAT_UPDATE_INTERVAL: float = 1.0  # Update heat every second
var all_lights = []
var base_light_energy = {}
var initial_fog_density = 0.0
var light_refresh_timer: float = 0.0
const LIGHT_REFRESH_INTERVAL: float = 5.0  # Refresh lights every 5 seconds

# Sound player
var coolant_sound_player: AudioStreamPlayer3D

# Add color constants
const COLD_COLOR := Color(0.2, 0.8, 0.2)  # Green
const HOT_COLOR := Color(0.8, 0.2, 0.2)   # Red

func _ready():
	# Set up initial heat bar style
	update_heat_bar_color()
	add_to_group("generator")
	
	# Store the initial fog density
	if world_environment and world_environment.environment:
		initial_fog_density = world_environment.environment.volumetric_fog_density
	
	# Find all lights in the level
	#find_all_lights(get_node("/root/Level"))
	
	# Set up audio player for coolant sound
	setup_audio_player()
	
	# Set up UI for temperature display
	heat_needle = get_node("/root/Level/UI/TempDisplay/Needle")
	heat_label = get_node("/root/Level/UI/TempDisplay/Label")

func setup_audio_player():
	# Create audio player for coolant sound
	coolant_sound_player = AudioStreamPlayer3D.new()
	add_child(coolant_sound_player)
	
	# Load the sound
	var sound = load("res://audio/coolant_inserted.wav")
	if sound:
		coolant_sound_player.stream = sound
		# Set properties
		coolant_sound_player.max_distance = 20.0
		coolant_sound_player.unit_size = 4.0
		coolant_sound_player.volume_db = 15.0
		coolant_sound_player.max_polyphony = 1


func find_all_lights(node):
	# Clear existing arrays to prevent duplicates if refreshing
	all_lights.clear()
	base_light_energy.clear()
	
	# Recursively find all lights in the scene
	_find_lights_recursive(node)


func _find_lights_recursive(node):
	# Recursively find all lights in the scene
	if node is Light3D and not node.is_in_group("flashlight"):
		all_lights.append(node)
		print("Light level changed for node")
		# Store the original energy for later reference
		base_light_energy[node] = node.light_energy
	
	for child in node.get_children():
		_find_lights_recursive(child)


func cleanup_lights_array():
	# Remove any invalid or freed lights from the array
	var valid_lights = []
	var valid_light_energies = {}
	
	for light in all_lights:
		if light and is_instance_valid(light):
			valid_lights.append(light)
			if base_light_energy.has(light):
				valid_light_energies[light] = base_light_energy[light]
	
	all_lights = valid_lights
	base_light_energy = valid_light_energies

@rpc("any_peer")
func red_heat(call_state: int, hl: int):
	if (call_state == 0):
		red_heat.rpc_id(1, 1, 0);
		return
	if (call_state == 1):
		if multiplayer.get_unique_id() != 1:
			return;
		heat_level = max(heat_level - 60.0, 0.0)
		red_heat.rpc(2, heat_level)
		hl = heat_level
	heat_level = hl;
	update_heat_bar_color()

func interact(player: Player) -> int:
	var item_socket = player.get_node("Head/ItemSocket")
	
	# Check if player is holding an item
	if item_socket.get_child_count() > 0:
		var held_item = item_socket.get_child(0)
		# Check if the held item is coolant
		if held_item.type == "coolant":
			# Remove coolant from player
			item_socket.remove_child(held_item)
			held_item.queue_free()
			heat_label
			# Reduce heat
			red_heat(0, 0)
			print("is coolant")
			
			# Play coolant insertion sound
			if coolant_sound_player and coolant_sound_player.stream:
				coolant_sound_player.play()
			
			# Update player inventory
			player.inventory[player.current_slot] = null
			player.inv_size -= 1
			player.is_holding = false
			
			# Update the tutorial tracking - set the has_refueled_generator flag
			player.has_refueled_generator = true
			
			# Update UI for the current player only
			if str(player.get_tree().get_multiplayer().get_unique_id()) == player.name:
				GameState.change_ui.emit(player.current_slot, "empty", 0)
				
			return 1  # Return 1 since this is a successful interaction
	print("not coolant")
	return 0  # Return 0 for no interaction

func _process(delta):
	# Accumulate time
	time_accumulator += delta
	
	# Check if a second has passed
	if time_accumulator >= HEAT_UPDATE_INTERVAL:
		# Reset accumulator and update heat
		time_accumulator = 0.0
		heat_level = min(heat_level + heat_increase_rate, max_heat)
		
		# Update the heat bar
		if heat_bar:
			heat_bar.value = heat_level
			update_heat_bar_color()
			
		# Update rotation of heat needle
		var heat_ratio = clamp(heat_level / max_heat, 0.0, 1.0)
		if heat_needle:
			var angle = lerp(NEEDLE_MIN_DEG, NEEDLE_MAX_DEG, heat_ratio)
			heat_needle.rotation_degrees = angle
		if heat_label:
			heat_label.text = "HEAT\n" + str(round(heat_ratio * 100)) + "%"
	
		# Update the energy bar from the electricity manager
		if electricity_manager and energy_bar:
			energy_bar.value = electricity_manager.electricity_level
		
		# Update lighting and fog based on heat level
		update_lighting_and_fog(heat_level)
	
	# Accumulate time for light refresh
	light_refresh_timer += delta
	if light_refresh_timer >= LIGHT_REFRESH_INTERVAL:
		light_refresh_timer = 0.0
		cleanup_lights_array()
		
		# Check if we need to refresh the list entirely
		#if all_lights.size() == 0:
			#find_all_lights(get_node("/root/Level"))

func update_lighting_and_fog(current_heat):
	# Calculate heat percentage (0-100)
	var heat_percent = current_heat / max_heat * 100.0
	
	# Calculate the number of 5% increments gained
	var five_percent_increments = int(heat_percent / 5)
	
	# Update fog density
	# Fog starts at 0.001 and increases 0.005 for each 5% heat gained
	if world_environment and world_environment.environment:
		var fog_density = 0.001 + (five_percent_increments * 0.005)
		world_environment.environment.volumetric_fog_density = fog_density
	
	# Update lighting
	# Reduce light energy by 2% for each 5% heat gained
	for light in all_lights:
		if light and is_instance_valid(light) and base_light_energy.has(light):
			var original_energy = base_light_energy[light]
			var reduction_factor = 1.0 - (five_percent_increments * 0.02)
			light.light_energy = original_energy * max(reduction_factor, 0.0)
	
	# If heat maxes out at 100, blackout happens
	if current_heat >= max_heat:
		complete_blackout()

func complete_blackout():
	# Set all lights to zero
	for light in all_lights:
		if light and is_instance_valid(light):
			light.light_energy = 0.0
	
	# Maximize fog
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_density = 0.1

func update_heat_bar_color():
	if not heat_bar:
		return
		
	# Create a new style box for the heat bar
	var style = heat_bar.get_theme_stylebox("fill").duplicate()
	
	# Interpolate between cold and hot colors based on heat level
	var t = heat_level / max_heat
	var current_color = COLD_COLOR.lerp(HOT_COLOR, t)
	
	# Set the color
	style.bg_color = current_color
	
	# Apply the style
	heat_bar.add_theme_stylebox_override("fill", style)
