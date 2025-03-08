@icon("res://console folder/icons/command.png")
class_name Command
extends Node

enum ArgumentType { FLOAT, INT, STRING }

@export var argument_names: Array[String] = []
@export var argument_types: Array[ArgumentType] = []
@export var help: String = ""

var _callback: String
var callback: String:
	get:
		return _callback
	set(value):
		_callback = "on_command_" + value

func _ready() -> void:
	if argument_types.size() != argument_names.size():
		push_error("Argument types and names must have the same size.")
	
	if str(name).find(" ") != -1:
		push_error("Command name must not contain spaces.")
	
	name = str(name).to_lower()  # Ensure command name is lowercase

# ---------------------------------------------------------
# Main entry point to execute the command with given args
# ---------------------------------------------------------
func execute_command(args: String) -> void:
	var parsed = parse_arguments(args)
	
	# If parse_arguments returns a String, it's an error message
	if parsed is String:
		# Replace push_error with your console UI error reporting method
		push_error("%s: %s\n%s" % [name, parsed, get_usage()])
		return
	
	# Verify the parent has the callback method
	if not get_parent().has_method(callback):
		push_error("Callback method '%s' not found on parent." % callback)
		return
	
	# Use call_deferred with callv to pass arguments correctly
	get_parent().call_deferred("callv", callback, parsed)



# ---------------------------------------------------------
# Splits the raw input text and converts each argument
# to match the specified ArgumentType, or returns an
# error string if something goes wrong.
# ---------------------------------------------------------
func parse_arguments(args: String) -> Variant:
	var arg_array = []
	var segmented = args.split(" ", false)
	var grouped: Array[String] = []
	
	var quoted = false
	for segment in segmented:
		if segment.begins_with("\""):
			quoted = true
			segment = segment.substr(1)  # Remove leading quote
		
		if segment.ends_with("\""):
			quoted = false
			segment = segment.substr(0, segment.length() - 1)  # Remove trailing quote
			grouped.append(segment)
			arg_array.append(" ".join(grouped))
			grouped.clear()
			continue
		
		if quoted:
			grouped.append(segment)
		else:
			arg_array.append(segment)
	
	# If we're still in quoted mode, we have a mismatched quote
	if not grouped.is_empty():
		return "Invalid argument format (Incomplete quote): '%s'" % " ".join(grouped)
	
	# Verify argument count
	if arg_array.size() != argument_types.size():
		return "Invalid number of arguments (Expected: %d, Received: %d)" % [
			argument_types.size(),
			arg_array.size()
		]
	
	# Convert each argument to required type
	for i in range(argument_types.size()):
		var arg = arg_array[i]
		
		match argument_types[i]:
			ArgumentType.FLOAT:
				if not arg.is_valid_float():
					return "Invalid float value: '%s'" % arg
				arg_array[i] = arg.to_float()
			
			ArgumentType.INT:
				if not arg.is_valid_int():
					return "Invalid integer value: '%s'" % arg
				arg_array[i] = arg.to_int()
			
			ArgumentType.STRING:
				# No conversion needed
				pass
	
	return arg_array

# ---------------------------------------------------------
# Returns a string showing how to use the command,
# for example: "Usage: echo <message:string>"
# ---------------------------------------------------------
func get_usage() -> String:
	var usage = "Usage: %s" % name
	for i in range(argument_types.size()):
		var type_name = ArgumentType.keys()[argument_types[i]].to_lower()
		usage += " <%s:%s>" % [argument_names[i].to_lower(), type_name]
	return usage

# ---------------------------------------------------------
# Utility for finding a relative namespace (not strictly
# necessary for error handling, but left as-is)
# ---------------------------------------------------------
func get_namespace_to(target: Node) -> Array[String]:
	var local_namespace: Array[String] = []
	var node: Node = self
	
	while node != target:
		local_namespace.insert(0, node.name)
		node = node.get_parent()
		if node == null:
			break
	
	return local_namespace
