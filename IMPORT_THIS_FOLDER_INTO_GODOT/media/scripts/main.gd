extends Node2D

var Player = preload("res://media/scenes/player.tscn")
@onready var _player_spawn = %PlayerSpawn

var Enemy = preload("res://media/scenes/twoface.tscn")
@onready var _enemy_spawn = %EnemySpawn

@onready var _health_bar = $HealthBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	inst(Player, _player_spawn.position)
	inst(Enemy, _enemy_spawn.position)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(update_health)
		update_health(player.health)

func inst(node, pos):
	var instance = node.instantiate()
	instance.position = pos
	add_child(instance)

func update_health(value):
	_health_bar.value = value
