extends Control

var host_pressed = false
var join_pressed = false

func host_game():
	if (host_pressed):
		return
	host_pressed = true
	print("become host pressed")
	MultiplayerManager.host_game()
func join_game():
	if (join_pressed):
		return
	join_pressed = true
	print("join game")
	MultiplayerManager.join_game()
