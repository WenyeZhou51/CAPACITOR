extends Node

<<<<<<< HEAD
var _quota = 100
=======
var _quota = 400
>>>>>>> master
var _team_score = 0

signal team_score_changed
signal end_game
signal change_ui

func get_quota() -> int:
	return _quota
	
func set_quota(val: int) -> void:
	_quota = val
	
func get_team_score() -> int:
	return _team_score

func set_team_score(val: int) -> void:
	_team_score = val
	team_score_changed.emit(_team_score)

func check_game_end() -> void:
	if (_team_score >= _quota):
		get_tree().change_scene_to_file("res://Scenes/win.tscn")
	
