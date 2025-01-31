extends Control


@export var text: String = "Default Text"  # Text to display in the popup
@onready var label: Label = $Label2  # Reference to the Label node
@onready var player = get_parent().get_node("Player")
var quota = 600

func _ready():
	# Set the text of the label
	label.text = str(quota)
	print(player)
	player.value_changed.connect(on_value_changed)

func on_value_changed(val: int):
	print("signal recieved")
	quota -= val
	label.text = str(quota)
