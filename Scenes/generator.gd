extends StaticBody3D

@export var sub_viewport: SubViewport
@export var heat_bar: ProgressBar
@export var energy_bar: ProgressBar
@onready var electricity_manager = get_node("/root/Level/Electricity Manager")
@onready var heat_warning = get_node("/root/Level/UI/HeatWarning")

@export var heat_level: float = 0.0
@export var heat_increase_rate: float = 1.0  # Heat units increased per second
@export var max_heat: float = 100.0

var time_accumulator: float = 0.0
const HEAT_UPDATE_INTERVAL: float = 1.0  # Update heat every second

# Add color constants
const COLD_COLOR := Color(0.2, 0.8, 0.2)  # Green
const HOT_COLOR := Color(0.8, 0.2, 0.2)   # Red

signal heat_danger
var player_notified: bool = false

func _ready():
	# Set up initial heat bar style
	update_heat_bar_color()
	add_to_group("generator")

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
			
			# Reduce heat
			heat_level = max(heat_level - 40.0, 0.0)
			update_heat_bar_color()
			print("is coolant")
			
			if heat_level < 0.8 * max_heat:
				player_notified = false
			
			player.inventory[player.current_slot] = null
			player.inv_size -= 1
			player.is_holding = false
			if (player.name == str(player.get_tree().get_multiplayer().get_unique_id())):
				GameState.change_ui.emit(player.current_slot, "empty")
			return 1  # Return 0 since this isn't a cash value interaction
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
			
		if heat_level > 0.8 * max_heat and not player_notified:
			# SEND ALARM TO PLAYERS
			#heat_danger.emit()
			heat_warning.warn_player()
			player_notified = true

	# Update the energy bar from the electricity manager
	if electricity_manager and energy_bar:
		energy_bar.value = electricity_manager.electricity_level

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
