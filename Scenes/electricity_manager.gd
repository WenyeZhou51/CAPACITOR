extends Node

@export var electricity_level: int = 100

var time_accumulator: float = 0.0
const DECREASE_INTERVAL: float = 1.0

func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= DECREASE_INTERVAL:
		time_accumulator = 0.0
		electricity_level = max(electricity_level - 1, 0)
