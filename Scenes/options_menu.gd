extends Control

@onready var click_back = $ClickBack # Reference the AudioStreamPlaye

# Audio bus indices
const MASTER_BUS = 0

# Default settings
var default_volume = 0.8
var default_brightness = 1.0

# Brightness shader
var brightness_shader = preload("res://shaders/brightness_shader.gdshader")
var shader_material

# Autoload for saving settings
var settings = {
	"volume": default_volume,
	"brightness": default_brightness
}

func _ready():
	# Set initial slider values from GlobalSettings
	$MarginContainer/VBoxContainer/TabContainer/Settings/VBoxContainer/VolumeSection/HBoxContainer/VolumeSlider.value = GlobalSettings.settings["volume"]
	$MarginContainer/VBoxContainer/TabContainer/Settings/VBoxContainer/BrightnessSection/HBoxContainer/BrightnessSlider.value = GlobalSettings.settings["brightness"]
	
	# Create shader material for brightness preview in options menu
	shader_material = ShaderMaterial.new()
	shader_material.shader = brightness_shader
	$Background.material = shader_material
	shader_material.set_shader_parameter("brightness", GlobalSettings.settings["brightness"])

func _on_volume_slider_value_changed(value):
	# Update global volume setting
	GlobalSettings.settings["volume"] = value
	GlobalSettings.apply_volume(value)
	GlobalSettings.save_settings()

func _on_brightness_slider_value_changed(value):
	# Update global brightness setting
	GlobalSettings.settings["brightness"] = value
	GlobalSettings.apply_brightness(value)
	
	# Also update local preview
	if shader_material:
		shader_material.set_shader_parameter("brightness", value)
	
	GlobalSettings.save_settings()

func _on_back_button_pressed():
	# Save settings and return to main menu
	click_back.play()
	GlobalSettings.save_settings()
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

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
