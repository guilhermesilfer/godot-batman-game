extends CharacterBody2D

enum State {
	IDLE,
	THROW,
	DROP_BOMB,
	JETPACK_TAKEOFF,
	JETPACK_CHARGE,
	JETPACK_LANDING,
	DAMAGE,
	DEAD
}

const SPEED = 0.0 
const JETPACK_SPEED = 100.0
const MAX_HEALTH = 100
const JETPACK_HEIGHT = 0.0 # Altura ideal para passar na cabeça do Batman

var health = MAX_HEALTH
var state = State.IDLE
var facing = -1 # -1 é Esquerda (padrão do seu sprite)
var start_y = 0.0 
var charge_direction = -1
var bomb_spawn_timer = 0.0

var BouncingBomb = preload("res://media/scenes/bouncing_bomb.tscn")
var ParachuteBomb = preload("res://media/scenes/parachute_bomb.tscn")

var _player: Node2D

@onready var _animated_sprite = $JokerAnimatedSprite
@onready var _throw_spawn = $ThrowSpawn
@onready var _collision = $JokerCollision
@onready var _jetpack_hitbox = $JetpackHitbox
@onready var _jetpack_col = $JetpackHitbox/CollisionShape2D

signal health_changed(new_health)
signal died

func _ready():
	health = MAX_HEALTH
	_jetpack_col.disabled = true
	_jetpack_hitbox.monitoring = false
	start_y = global_position.y
	
	_player = get_tree().get_first_node_in_group("player")
	
	# CONEXÃO COM OS LIMITES DA ARENA
	var limits = get_tree().get_nodes_in_group("arena_limit")
	for area in limits:
		if area is Area2D:
			if not area.body_entered.is_connected(_on_limit_body_entered):
				area.body_entered.connect(_on_limit_body_entered)
			
	if not _jetpack_hitbox.body_entered.is_connected(_on_jetpack_hitbox_body_entered):
		_jetpack_hitbox.body_entered.connect(_on_jetpack_hitbox_body_entered)
	
	start_cycle()

func _physics_process(delta):
	if state == State.DEAD: return
		
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	# Gravidade só funciona se não estiver decolando ou voando
	if state != State.JETPACK_TAKEOFF and state != State.JETPACK_CHARGE:
		if not is_on_floor():
			velocity += get_gravity() * delta
	else:
		velocity.y = 0

	match state:
		State.IDLE, State.THROW, State.DAMAGE, State.JETPACK_LANDING:
			velocity.x = 0
			update_facing()
			
		State.JETPACK_TAKEOFF:
			# Sobe suavemente
			global_position.y = move_toward(global_position.y, start_y + JETPACK_HEIGHT, 5.0)
			if abs(global_position.y - (start_y + JETPACK_HEIGHT)) < 2:
				start_jetpack_charge()
				
		State.JETPACK_CHARGE:
			velocity.x = charge_direction * JETPACK_SPEED
			
			# Chuva de bombas
			bomb_spawn_timer += delta
			if bomb_spawn_timer >= 0.4:
				spawn_auto_parachute_bomb()
				bomb_spawn_timer = 0.0

	move_and_slide()

# -------------------------
# IA E COMPORTAMENTO
# -------------------------

func start_cycle():
	if state == State.DEAD: return
	state = State.IDLE
	_animated_sprite.play("idle")
	
	await get_tree().create_timer(1.2).timeout
	if state != State.IDLE: return
	
	# RARIDADE DOS GOLPES
	var chance = randf()
	if chance < 0.15: # 15% Jetpack
		start_jetpack_init()
	elif chance < 0.50: # 35% Bomba Paraquedas
		start_drop_bomb()
	else: # 50% Bomba que Quica
		start_throw()

func start_throw():
	if state == State.DEAD: return
	state = State.THROW
	_animated_sprite.play("throw")
	
	await get_tree().create_timer(0.3).timeout
	if state == State.THROW:
		var bomb = BouncingBomb.instantiate()
		bomb.global_position = _throw_spawn.global_position
		if "facing" in bomb: bomb.facing = facing
		get_tree().current_scene.add_child(bomb)
	
	await _animated_sprite.animation_finished
	start_cycle()

func start_drop_bomb():
	if state == State.DEAD: return
	state = State.DROP_BOMB
	_animated_sprite.play("idle") 
	spawn_auto_parachute_bomb()
	await get_tree().create_timer(1.0).timeout
	start_cycle()

func spawn_auto_parachute_bomb():
	if _player == null: return
	var bomb = ParachuteBomb.instantiate()
	# Cai exatamente onde o Batman está no momento
	bomb.global_position = Vector2(_player.global_position.x, global_position.y - 250)
	get_tree().current_scene.add_child(bomb)

# -------------------------
# JETPACK (Voo e Limites)
# -------------------------

func start_jetpack_init():
	state = State.JETPACK_TAKEOFF
	_animated_sprite.play("jetpack_takeoff")

func start_jetpack_charge():
	if _player == null:
		start_landing()
		return
		
	state = State.JETPACK_CHARGE
	_animated_sprite.play("jetpack_charge")
	bomb_spawn_timer = 0.0 
	
	# Decide a direção para atravessar o player
	charge_direction = 1 if _player.global_position.x > global_position.x else -1
	set_direction(charge_direction)
	
	_jetpack_col.set_deferred("disabled", false)
	_jetpack_hitbox.set_deferred("monitoring", true)

func _on_limit_body_entered(body):
	# Se o Joker entrar num LimitLeft ou LimitRight enquanto voa, ele pousa
	if body == self and state == State.JETPACK_CHARGE:
		start_landing()

func start_landing():
	if state == State.JETPACK_LANDING: return
	state = State.JETPACK_LANDING
	
	_jetpack_col.set_deferred("disabled", true)
	_jetpack_hitbox.set_deferred("monitoring", false)
	
	_animated_sprite.play("jetpack_landing")
	
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", start_y, 0.4)
	
	await _animated_sprite.animation_finished
	# Como prometido: ao pousar, ele joga uma bomba de quicar
	start_throw() 

# -------------------------
# UTILITÁRIOS E DANOS
# -------------------------

func set_direction(dir):
	facing = dir
	_animated_sprite.flip_h = (dir == 1) # Invertido pois seu sprite olha para esquerda
	_throw_spawn.position.x = abs(_throw_spawn.position.x) * (1 if dir == 1 else -1)

func update_facing():
	if _player == null or state == State.DEAD: return
	if state == State.JETPACK_CHARGE or state == State.JETPACK_TAKEOFF: return
	
	var dir = 1 if _player.global_position.x > global_position.x else -1
	set_direction(dir)

func _on_jetpack_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"): body.take_damage(20)
		if body.has_method("heavy_stun"): body.heavy_stun()

func take_damage(damage = 1):
	if state == State.DEAD: return
	health = max(health - damage, 0)
	emit_signal("health_changed", health)
	
	if health <= 0:
		die()
	else:
		# Se estiver no chão, toca animação de dano
		if state != State.JETPACK_CHARGE:
			state = State.DAMAGE
			_animated_sprite.play("damage")
			await _animated_sprite.animation_finished
			start_cycle()

func die():
	state = State.DEAD
	_jetpack_col.set_deferred("disabled", true)
	_animated_sprite.play("death")
	await get_tree().create_timer(2.0).timeout
	emit_signal("died")
	queue_free()
