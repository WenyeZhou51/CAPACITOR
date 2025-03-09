extends Control

@export var loadingBar: ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Loader.LOADING_PROGRESS_UPDATED.connect(_on_progress_updated)

func _on_progress_updated(percentage):
	loadingBar.value = percentage
