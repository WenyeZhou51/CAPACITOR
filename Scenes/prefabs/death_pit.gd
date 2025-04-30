extends Area3D

@export var damage_per_second: float = 1000.0  # Massive damage to ensure instant death
var overlapping_players: Array[CharacterBody3D] = []

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# Apply damage to all overlapping players
	for player in overlapping_players:
		print("overlapping")
		if player and is_instance_valid(player):
			print("taking dmg")
			player.init_take_damage(damage_per_second)

func _on_body_entered(body: Node3D) -> void:
	print("entered")
	if body.is_in_group("players"):
		overlapping_players.append(body)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		overlapping_players.erase(body)
