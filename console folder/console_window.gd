extends PanelContainer

@onready var input_bar: Control = $VBoxContainer/InputBar
@onready var display: Control = $VBoxContainer/ScrollContainer/Display
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer

@export var message_buffer_limit: int = 100

var message_buffer: PackedStringArray = PackedStringArray()
var command_modules: Array = []

func _ready():
	focus_entered.connect(_on_focus)
	mouse_entered.connect(_on_mouse_enter)
	
func _on_focus():
	$VBoxContainer/InputBar.grab_focus()

func _on_mouse_enter():
	$VBoxContainer/InputBar.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Manually scroll up
			scroll_container.scroll_vertical -= 30
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Manually scroll down
			scroll_container.scroll_vertical += 30
			get_viewport().set_input_as_handled()

func add_command_module(module: CommandModule):
	module.console = self
	command_modules.push_back(module)

func push_message(msg: String):
	message_buffer.append(msg)
	if message_buffer.size() > message_buffer_limit:
		message_buffer.remove_at(0)

	var result = ""
	for i in range(message_buffer.size()):
		if i > 0:
			result += "\n"
		result += message_buffer[i]

	display.bbcode_text = result

func clear_output():
	message_buffer = PackedStringArray()
	display.text = ""

func _gui_input(event: InputEvent) -> void:
	print("receiving gui input on console side")
	# Skip processing for mouse wheel events to ensure they're handled by _unhandled_input
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		return
		
	if visible and $VBoxContainer/InputBar.has_focus():
		# Handle special keys and accept input
		if event.is_action_pressed("ui_accept"):
			accept_event()
		elif event is InputEventKey:
			accept_event()

func parse_input(input: String):
	var tokenized = input.split(" ", false, 1)
	if tokenized.size() == 0:
		return

	var command = tokenized[0].to_lower()
	var command_module = null
	for module in command_modules:
		if module.has_command(command):
			command_module = module
			break

	if command_module == null:
		push_message("Syntax Error")
		return

	var args = ""
	if tokenized.size() > 1:
		args = tokenized[1]

	command_module.command_entered(command, args)

func _on_input_bar_text_submitted(text: String):
	input_bar.clear()
	if text.length() == 0:
		return
	parse_input(text)
