extends Node

signal LOADING_PROGRESS_UPDATED(percentage)

@export var loadingScene = preload("res://Scenes/ui/loading_screen.tscn").instantiate()

var scenePath

func loadScene(caller, path):
	scenePath = path
	
	get_tree().root.add_child(loadingScene)
	
	ResourceLoader.load_threaded_request(scenePath)
	
	caller.queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (scenePath != null):
		var progress = []
		var loaderStatus = ResourceLoader.load_threaded_get_status(scenePath, progress)
		
		if (loaderStatus == ResourceLoader.THREAD_LOAD_LOADED):
			var loadedScene = ResourceLoader.load_threaded_get(scenePath).instantiate()
			
			get_tree().root.remove_child(loadingScene)
			get_tree().root.add_child(loadedScene)
			
			scenePath = null
		elif (loaderStatus == ResourceLoader.THREAD_LOAD_IN_PROGRESS):
			LOADING_PROGRESS_UPDATED.emit(progress[0])
