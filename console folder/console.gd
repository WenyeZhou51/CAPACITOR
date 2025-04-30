extends CSGBox3D

@onready var console_ui = $SubViewport/ConsoleWindow
@onready var console_light = $ConsoleLight
@onready var screen_material = $CSGBox3D/MeshInstance3D.get_surface_override_material(0)

var normal_light_energy = 1.5
var active_light_energy = 3.0
var player_using_console = false

var base_emission_energy = 2.0
var active_emission_energy = 4.0

func _ready():
	add_to_group("console")
	$"Console Interaction Area".add_to_group("console")
	$SubViewport.handle_input_locally = true 
	$SubViewport.gui_disable_input = false
	$SubViewport.gui_embed_subwindows = true
	
	# Connect to signal from player toggling console
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("toggle_console"):
			player.connect("console_toggled", _on_console_toggled)

func _on_console_toggled(is_using: bool) -> void:
	player_using_console = is_using
	_update_console_visibility()

# Add process method to ensure light adjusts even when player enters/exits console while already close
func _process(_delta: float) -> void:
	var players_nearby = false
	for body in $"Console Interaction Area".get_overlapping_bodies():
		if body.is_in_group("players") and body.near_console:
			players_nearby = true
			break
	
	# Check environment light level if possible
	var environment_brightness = _get_environment_brightness()
	
	# Update console visibility based on player presence and environment
	_update_console_visibility(players_nearby, environment_brightness)

# Get approximate brightness of the environment
func _get_environment_brightness() -> float:
	# Check for WorldEnvironment or other light sources
	var environment = get_viewport().get_camera_3d().get_environment()
	var brightness = 1.0
	
	if environment:
		# Get ambient light intensity
		if environment.ambient_light_energy > 0:
			brightness = environment.ambient_light_energy
		
		# Adjust for fog if present (which might obscure the console)
		if environment.fog_enabled:
			brightness *= (1.0 - min(environment.fog_density * 0.5, 0.8))
			
	return brightness

# Update console visibility based on current conditions
func _update_console_visibility(players_nearby: bool = false, environment_brightness: float = 1.0) -> void:
	# Base multiplier on environmental conditions (darker environment = brighter console)
	var darkness_factor = max(1.0, 2.0 / max(environment_brightness, 0.5))
	
	if player_using_console:
		# When player is using console, make it very bright
		console_light.light_energy = active_light_energy
		if screen_material:
			screen_material.emission_energy_multiplier = active_emission_energy * darkness_factor
	elif players_nearby:
		# When player is nearby but not using, make it moderately bright
		console_light.light_energy = normal_light_energy * 1.3
		if screen_material:
			screen_material.emission_energy_multiplier = base_emission_energy * 1.5 * darkness_factor
	else:
		# Default state - still visible but not as bright
		console_light.light_energy = normal_light_energy
		if screen_material:
			screen_material.emission_energy_multiplier = base_emission_energy * darkness_factor
