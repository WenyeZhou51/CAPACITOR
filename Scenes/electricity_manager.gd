extends Node

@export var electricity_level: int = 100

var time_accumulator: float = 0.0
const DECREASE_INTERVAL: float = 1.0
var energy_drain_rate: float = 1.0 # Energy units decreased per second, will be set by generator

func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= DECREASE_INTERVAL:
		time_accumulator = 0.0
		electricity_level = max(electricity_level - energy_drain_rate, 0)
