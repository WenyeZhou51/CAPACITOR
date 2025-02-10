extends Control

@export var text: String = "Default Text"  # Text to display in the popup
@onready var label: Label = $Label2  # Reference to the Label node
@onready var player = get_parent().get_node("Player")
@onready var grid_container = $ninepatch/GridContainer
var quota = 600

func _ready():
	# Set the text of the label
	label.text = str(quota)
	player.value_changed.connect(on_value_changed)
	player.change_ui.connect(on_change_ui)
	player.inv_high.connect(update_highlight)
	var first = grid_container.get_child(0)
	first.self_modulate = Color(1,1,1,1)

func on_value_changed(val: int):
	#print("signal recieved")
	quota -= val
	label.text = str(quota)
	
func swap_UI(idx: int, new_scene: PackedScene):
	var old_child = grid_container.get_child(idx)
	grid_container.remove_child(old_child)
	old_child.queue_free()

	var new_instance = new_scene.instantiate()
	new_instance.self_modulate = Color(1,1,1,1)

	# Add the new instance and move it to the correct index
	grid_container.add_child(new_instance)
	grid_container.move_child(new_instance, idx)

func on_change_ui(idx: int, item: String):
	var new_scene: PackedScene
	if(item == "empty"):
		new_scene = load("res://imgs/inv_slot_ui.tscn")
		show_text("")
	elif(item == "flash"):
		new_scene = load("res://imgs/flash_slot.tscn")
		show_text(item)
	elif(item == "coolant"):
		new_scene = load("res://imgs/coolant_slot.tscn")
		show_text(item)
	else:
		new_scene = load("res://imgs/scrap_slot.tscn")
		show_text(item)
	swap_UI(idx, new_scene)

func update_highlight(previous_idx: int, curr_idx: int, name: String):
	show_text(name)
	if(previous_idx == curr_idx):
		return  # No need to update if selection hasn't changed
	var old_child = grid_container.get_child(previous_idx)
	old_child.self_modulate = Color(0, 0, 0, 0)
	
	var curr_child = grid_container.get_child(curr_idx)
	curr_child.self_modulate = Color(1,1,1,1)

func show_text(popup_text: String):
	var label = get_node("Label3")
	label.text = popup_text
	label.modulate = Color(1, 1, 1, 1)
