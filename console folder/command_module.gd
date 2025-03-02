@icon("res://console folder/icons/command module.png")
extends Node
class_name CommandModule

@export var command_handler_target: NodePath = ".."
@export var module_description: String = ""

var command_refs: Dictionary = {}
var command_handler: Node = null
var console: Node = null

func _ready() -> void:
	command_handler = get_node(command_handler_target)
	_build_command_dictionary(self)

func command_entered(command: String, args: String) -> void:
	var command_node = command_refs.get(command, null)
	if command_node == null:
		console.push_message("Unknown command: " + command)
		return


	var parse_result = command_node.parse_arguments(args)
	# If parse_result is a string, it contains an error message
	if parse_result is String:
		console.push_message(parse_result)
		console.push_message(command_node.get_usage())
		return
	
	# Add safety check for argument count before execution
	if parse_result.size() != command_node.argument_types.size():
		console.push_message("Error: Incorrect number of arguments")
		console.push_message(command_node.get_usage())
		return
	
	# If the command's callback method does not exist, display an internal error
	if not command_handler.has_method(command_node.callback):
		console.push_message("Internal error: Command callback not found: " + command_node.callback)
		return

	# Everything is good, let's call the command’s function
	if parse_result is Array:
		command_handler.call(command_node.callback, console, parse_result)
	else:
		console.push_message("Error executing command: " + command)

func has_command(command: String) -> bool:
	return command_refs.has(command)

func _build_command_dictionary(target: Node) -> void:
	for child in target.get_children():
		if not (child is Command or child is CommandGroup):
			push_error("Child is not a valid command type")
			continue
		
		if child is Command:
			var namespace_arr = child.get_namespace_to(self)
			# Setting the callback will prepend "on_command_"
			child.callback = "_".join(namespace_arr)
			command_refs[".".join(namespace_arr)] = child

		else:
			_build_command_dictionary(child)

func generate_help_string() -> String:
	var msg = "Module: " + name
	msg += " {}\n\n".format(module_description)
	
	for command_string in command_refs.keys():
		var command_node = command_refs[command_string]
		msg += "* {}\n".format(command_string)
		msg += "    {}\n".format(command_node.help)
	
	return msg
