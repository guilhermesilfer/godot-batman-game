extends Node2D

var Player = preload("res://media/scenes/player.tscn")
@onready var _player_spawn = %PlayerSpawn
@onready var _enemy_spawn = %EnemySpawn
@onready var _ingame_song = $IngameSong

var bosses = [
	preload("res://media/scenes/twoface.tscn"),
	preload("res://media/scenes/ivy.tscn"),
	preload("res://media/scenes/bane.tscn"),
	preload("res://media/scenes/joker.tscn")
]

# Nova lista com os ícones na MESMA ORDEM dos chefões acima!
var boss_icons = [
	preload("res://media/sprites/twoface/twoface_icon.png"), # Ajuste o caminho do PNG do Two-Face
	preload("res://media/sprites/ivy/ivy_icon.png"),     # Ajuste o caminho do PNG da Ivy
	preload("res://media/sprites/bane/bane_icon.png"),    # Ajuste o caminho do PNG do Bane
	preload("res://media/sprites/joker/joker_icon.png")    # Ajuste o caminho do PNG do Joker
]

var current_boss_index := 0
var current_boss = null

@onready var _health_bar = $HealthBar

# Puxando a nova barra e o ícone
@onready var _enemy_health_bar = $EnemyHealthBar
@onready var _enemy_icon = $EnemyHealthBar/EnemyIcon

func _ready() -> void:
	_ingame_song.play()
	spawn_boss()
	inst(Player, _player_spawn.position)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(update_health)
		update_health(player.health)

func spawn_boss():
	if current_boss_index >= bosses.size():
		get_tree().change_scene_to_file("res://media/scenes/win_screen.tscn")
		return
	
	var boss_scene = bosses[current_boss_index]
	current_boss = boss_scene.instantiate()
	current_boss.position = _enemy_spawn.position
	
	add_child(current_boss)
	
	# Troca a imagem do ícone para o chefão atual
	_enemy_icon.texture = boss_icons[current_boss_index]
	
	# Conecta os sinais de dano e morte
	current_boss.health_changed.connect(enemy_update_health)
	current_boss.died.connect(_on_boss_died)
	
	# Restaura a barra de vida para 100% no início da luta
	enemy_update_health(current_boss.health)

func _on_boss_died():
	print("Boss morreu")
	
	current_boss_index += 1
	
	if current_boss:
		current_boss = null
	
	show_next_menu()

func show_next_menu():
	var menu = preload("res://media/scenes/next_boss_menu.tscn").instantiate()
	add_child(menu)
	
	menu.next_pressed.connect(start_next_boss)

func start_next_boss():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health = 100
		update_health(player.health)
	spawn_boss()

func inst(node, pos):
	var instance = node.instantiate()
	instance.position = pos
	add_child(instance)

func update_health(value):
	_health_bar.value = value

# Função que faltava para atualizar a barra do inimigo
func enemy_update_health(value):
	_enemy_health_bar.value = value
