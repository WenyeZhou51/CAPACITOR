extends Node

var _quota = 400
var _team_score = 0
var alive_count = 0

var players = {}

signal team_score_changed
signal end_game
signal change_ui
signal inv_high

func get_quota() -> int:
	return _quota
	
func set_quota(val: int) -> void:
	_quota = val
	
func get_team_score() -> int:
	return _team_score

#func playerUpdate()

func set_team_score(val: int) -> void:
	_team_score = val
	team_score_changed.emit(_team_score)

func check_game_end() -> void:
	if (_team_score >= _quota):
		get_tree().change_scene_to_file("res://Scenes/win.tscn")
	elif alive_count <= 0:
		get_tree().change_scene_to_file("res://Scenes/Gameover.tscn")
	
func reduce_alive_count() -> void:
	alive_count -= 1
	check_game_end()
	
func get_player_node_by_name(name: String) -> Player:
	return get_tree().get_root().get_node_or_null("Level/players/" + name)
