extends Control

@export var heat_bar: ProgressBar
@export var energy_bar: ProgressBar

@export var heat_level: float = 0.0
@export var heat_increase_rate: float = 1.0  # Heat units increased per second
@export var max_heat: float = 100.0

@onready var electricity_manager = get_node("/root/Electricity Manager")

var time_accumulator: float = 0.0
const HEAT_UPDATE_INTERVAL: float = 1.0  # Update heat every second

# Add color constants
const COLD_COLOR := Color(0.2, 0.8, 0.2)  # Green
const HOT_COLOR := Color(0.8, 0.2, 0.2)   # Red

func _ready():
	# Set up initial heat bar style
	update_heat_bar_color()

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

	# Update the energy bar from the electricity manager
	if electricity_manager and energy_bar:
		energy_bar.value = electricity_manager.electricity_level

func update_heat_bar_color():
	if not heat_bar:
		return
		
	# Calculate the interpolation factor (0.0 to 1.0)
	var t = heat_level / max_heat
	
	# Interpolate between green and red
	var current_color = COLD_COLOR.lerp(HOT_COLOR, t)
	
	# Get the style box and update its color
	var style = heat_bar.get_theme_stylebox("fill").duplicate()
	style.bg_color = current_color
	heat_bar.add_theme_stylebox_override("fill", style)
