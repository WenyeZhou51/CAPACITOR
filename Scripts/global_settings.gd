extends Node

# Default settings
var default_volume = 0.8
var default_brightness = 1.0

# Audio bus indices
const MASTER_BUS = 0

# Brightness shader
var brightness_shader = preload("res://shaders/brightness_shader.gdshader")
var shader_material

# Current settings
var settings = {
	"volume": default_volume,
	"brightness": default_brightness
}

func _ready():
	# Load settings
	load_settings()
	
	# Create shader material for brightness
	shader_material = ShaderMaterial.new()
	shader_material.shader = brightness_shader
	
	# Apply settings
	apply_volume(settings["volume"])
	apply_brightness(settings["brightness"])

func apply_volume(value):
	# Set the master bus volume
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(value))

func apply_brightness(value):
	# Apply brightness using shader
	if shader_material:
		shader_material.set_shader_parameter("brightness", value)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "volume", settings["volume"])
	config.set_value("video", "brightness", settings["brightness"])
	config.save("user://settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		settings["volume"] = config.get_value("audio", "volume", default_volume)
		settings["brightness"] = config.get_value("video", "brightness", default_brightness)
	else:
		# If settings file doesn't exist, use defaults
		settings["volume"] = default_volume
		settings["brightness"] = default_brightness
		
	# Apply loaded settings
	apply_volume(settings["volume"])
	apply_brightness(settings["brightness"])

# Function to get the brightness shader material
func get_brightness_material():
	return shader_material 