extends Node


# Add these variables at the top
@export var item_scenes: Array[PackedScene] = []
@export var console_spawn_point: NodePath
@export var camera_viewport_scene: PackedScene

func _ready() -> void:
	get_parent().add_command_module($Console)
	
func on_command_buy(console: Node, args: Array):
	var item_name: String = args[0]
	var amount: int = args[1]
	var spawn_node = get_node_or_null(console_spawn_point)
	
	if not spawn_node:
		console.push_message("Error: No spawn point configured")
		return
	
	var found_scene: PackedScene
	for scene in item_scenes:
		if scene.resource_path.get_file().trim_suffix(".tscn").to_lower() == item_name.to_lower():
			found_scene = scene
			break
	
	if not found_scene:
		console.push_message("Error: Item not found - " + item_name)
		return
	
	# Get the item type to determine which constant to use
	var item_type = Constants.ITEMS.FLASHLIGHT  # Default to flashlight
	
	# Check the item name to set the correct item type
	if item_name.to_lower() == "coolant":
		item_type = Constants.ITEMS.COOLANT
	elif item_name.to_lower() == "flashlight":
		item_type = Constants.ITEMS.FLASHLIGHT
	
	for i in amount:
		var instance = found_scene.instantiate()
		instance.global_transform = spawn_node.global_transform
		
		# Use the appropriate item type constant
		MultiplayerRequest.request_item_spawn(item_type, spawn_node.global_transform)
		
		# Update tutorial progress for level 2 if player bought coolant
		var player = _find_player()
		if player and item_name.to_lower() == "coolant":
			player.has_bought_coolant = true
		
	console.push_message("Transaction Processed!")

# Helper function to find the player
func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func on_command_clear(console, args):
	console.clear_output()
func on_command_query(console: Node, args: Array):
	var knowledge_base = {
		"scrap": "Recyclable metal fragments, contain salvagable parts or components",
		"coolant": "Required for generator maintenance. Prevents reactor meltdowns",
		"venus": "Hostile statue-like entity. Avoid direct contact",
		"generator": "Core power system. Requires regular coolant injections",
		"console": "Command Line Interface. BASIC subsystem. Type 'help' for commands"
	}
	
	var subject = args[0].to_lower()
	if knowledge_base.has(subject):
		console.push_message("[%s]: %s" % [subject.capitalize(), knowledge_base[subject]])
	else:
		console.push_message("Subject '%s' not found in database" % subject)
	
func on_command_cam(console: Node, args: Array):
	var target_name = args[0]
	var players = get_tree().get_nodes_in_group("players")
	
	# Find target player
	var target_player = null
	for player in players:
		if player.name == target_name:
			target_player = player
			break
	
	if not target_player:
		console.push_message("Error: Player not found - " + target_name)
		return
		
	# Get the console root node and screen mesh
	var console_root = console.get_parent().get_parent()
	var console_screen = console_root.get_node("CSGBox3D/MeshInstance3D")
	
	# Get or create viewport container
	var viewport_container = console.get_node_or_null("CameraViewport")
	if viewport_container:
		viewport_container.queue_free()
	
	viewport_container = camera_viewport_scene.instantiate()
	
	# Add viewport to the console's SubViewport node
	console_root.get_node("SubViewport").add_child(viewport_container)
	
	# Set target player
	viewport_container.set_target(target_player)
	console.push_message("Now viewing: " + target_name)

func on_command_help(console: Node, args: Array):
	var help_text = "Console Commands:\n"
	
	# Get all command modules from the console window
	var command_modules = console.command_modules
	
	if command_modules.size() > 0:
		for module in command_modules:
			var commands = module.command_refs
			
			# Add each command to the help text
			for cmd_name in commands.keys():
				var cmd = commands[cmd_name]
				help_text += "\n" + cmd.get_usage() + "\n"
				help_text += "  " + cmd.help + "\n"
	else:
		help_text += "\nNo commands available.\n"
	
	# Add a note about game controls
	help_text += "\n--- Game Controls ---\n"
	help_text += "WASD - Move\n"
	help_text += "Space - Jump\n"
	help_text += "E - Interact\n"
	help_text += "Q - Drop\n"
	help_text += "Shift - Run\n"
	help_text += "Left mouse - Toggle flashlight\n"
	help_text += "ESC - Exit console"
	
	console.push_message(help_text)
	
	# Update player's has_typed_help property for tutorial tracking
	var player = _find_player()
	if player:
		player.has_typed_help = true

func on_command_cobson(console: Node, args: Array):
	GameState.instant_win()
