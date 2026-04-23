extends CharacterBody2D

# Sistema de estados adaptado para incluir preparação e investida
enum State {
	SHOOT,
	LOAD,    # Estado onde ele fica parado e vermelho
	CHARGE,  # Investida com zigue-zague
	RECOVER,
	DEAD
}

const SPEED = 220.0
const MAX_HEALTH = 100
const NORMAL_FIRE_RATE = 1.0
const FAST_FIRE_RATE = 0.4
const LEFT_WALL = 45.0   # Limites de arena baseados no Bane
const RIGHT_WALL = 275.0

var Bullet = preload("res://media/scenes/projectile.tscn")

var is_berserk := false
var charge_count := 0
var max_charges := 1
var is_phase_two := false
var facing := -1
var state = State.SHOOT
var charge_direction = 1
var shots_fired = 0
var shots_target = 0
var health = MAX_HEALTH
var damage_taken_in_shoot := 0

var _player: Node2D

@onready var _bullet_spawn = $TFBulletSpawn
@onready var _animated_sprite = $TFAnimatedSprite2D
@onready var _collision_charge_area = $TFChargeCollision
@onready var _collision_charge = $TFChargeCollision/CollisionShape2D
@onready var _fire_timer = $TFFireRate
@onready var _shot_sound = $ShotSound
@onready var _twoface_laugh_sound = $TwofaceLaugh

signal health_changed(new_health)
signal died

func _ready():
	_fire_timer.wait_time = NORMAL_FIRE_RATE
	health = MAX_HEALTH
	_bullet_spawn.position.x *= facing
	_collision_charge.position.x *= facing
	_animated_sprite.flip_h = (facing == -1)
	_collision_charge.disabled = true
	
	_player = get_tree().get_first_node_in_group("player")
	
	start_shoot_cycle()

func _physics_process(delta):
	if state == State.DEAD: return

	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.CHARGE:
			velocity.x = charge_direction * SPEED
			check_walls() # Lógica de zigue-zague
		State.LOAD, State.RECOVER, State.SHOOT:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _process(_delta):
	if state == State.DEAD: return
	
	# Busca o player se a referência estiver vazia ou se o objeto foi deletado
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	
	match state:
		State.LOAD, State.RECOVER:
			var direction = sign(_player.global_position.x - global_position.x)
			set_direction(direction)
			_animated_sprite.play("halt")
		State.SHOOT:
			_animated_sprite.play("shoot")
		State.CHARGE:
			_animated_sprite.play("run")

# --- LÓGICA DE MOVIMENTO EM ZIGUE-ZAGUE ---
func check_walls():
	if global_position.x <= LEFT_WALL and charge_direction == -1:
		bounce()
	elif global_position.x >= RIGHT_WALL and charge_direction == 1:
		bounce()

func bounce():
	charge_count += 1
	if charge_count >= max_charges:
		end_charge()
	else:
		charge_direction *= -1
		set_direction(charge_direction)

# --- CICLO DE ATAQUE ---
func start_shoot_cycle():
	shots_fired = 0
	shots_target = randi_range(3, 6)
	state = State.SHOOT
	damage_taken_in_shoot = 0

func fire():
	if state != State.SHOOT or shots_fired >= shots_target: return
	
	var bullet = Bullet.instantiate()
	_shot_sound.play()
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	get_tree().current_scene.add_child(bullet)
	
	shots_fired += 1
	if shots_fired >= shots_target:
		prepare_charge()

# --- SISTEMA DE CARGA COM AVISO VERMELHO ---
func prepare_charge():
	state = State.LOAD
	
	# Efeito visual: Fica vermelho para indicar perigo
	var tween = create_tween()
	tween.tween_property(_animated_sprite, "modulate", Color.RED, 0.5)
	
	await get_tree().create_timer(1.0).timeout
	
	# Volta ao normal e inicia a investida
	_animated_sprite.modulate = Color.WHITE
	if state == State.DEAD: return
	
	start_charge()

func start_charge():
	state = State.CHARGE
	charge_count = 0
	# Define direção inicial baseada na posição para cruzar a tela
	charge_direction = 1 if global_position.x < 160 else -1
	set_direction(charge_direction)
	
	_collision_charge.disabled = false
	_collision_charge_area.monitoring = true

func end_charge():
	_collision_charge.disabled = true
	_collision_charge_area.monitoring = false
	velocity.x = 0
	state = State.RECOVER
	
	var recover_time = 0.5 if is_berserk else 1.0
	await get_tree().create_timer(recover_time).timeout
	
	if state != State.DEAD:
		start_shoot_cycle()

# --- UTILITÁRIOS ---
func set_direction(dir):
	if dir == 0 or facing == dir: return
	facing = dir
	_collision_charge.position.x = abs(_collision_charge.position.x) * dir
	_bullet_spawn.position.x = abs(_bullet_spawn.position.x) * dir
	_animated_sprite.flip_h = (dir == -1)

func take_damage(damage = 6):
	if state == State.DEAD: return
	
	var tween = create_tween()
	_animated_sprite.modulate = Color(10, 10, 10)
	tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.15)
	
	health = max(health - damage, 0)
	emit_signal("health_changed", health)
	
	if health <= 0:
		die()
		return
	
	# Mudanças de fase baseadas na vida
	if health <= 40 and not is_phase_two:
		is_phase_two = true
		_fire_timer.wait_time = FAST_FIRE_RATE
	
	if health <= 15 and not is_berserk:
		is_berserk = true
		max_charges = 3 # Aumenta zigue-zague no berserk
	
	# Se levar muito dano parado, ele tenta fugir com charge
	if state == State.SHOOT:
		damage_taken_in_shoot += damage
		if damage_taken_in_shoot >= 15:
			prepare_charge()

func die():
	state = State.DEAD
	velocity = Vector2.ZERO
	_animated_sprite.modulate = Color.WHITE # Garante que não morra vermelho
	_collision_charge.set_deferred("disabled", true)
	_collision_charge_area.set_deferred("monitoring", false)
	
	# Desativa todas as colisões
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	
	_animated_sprite.play("death")
	await get_tree().create_timer(1.5).timeout
	emit_signal("died")
	queue_free()

func _on_tf_fire_rate_timeout():
	if state == State.SHOOT:
		fire()

func _on_tf_charge_collision_body_entered(body: Node2D) -> void:
	if state == State.DEAD: return
	
	if body.is_in_group("player"):
		if body.is_invulnerable or body.is_dead:
			return
			
		if body.has_method("take_damage"):
			body.take_damage(20)
			_twoface_laugh_sound.play()
			
		if body.has_method("heavy_stun"):
			body.heavy_stun()
