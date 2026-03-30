extends CharacterBody2D

enum State {
	SHOOT,
	CHARGE,
	RECOVER
}

const SPEED = 220.0
const MAX_HEALTH = 100
const NORMAL_FIRE_RATE = 1.0
const FAST_FIRE_RATE = 0.4

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

func _ready():
	_fire_timer.wait_time = NORMAL_FIRE_RATE
	health = MAX_HEALTH
	_bullet_spawn.position.x *= facing
	_collision_charge.position.x *= facing
	_animated_sprite.flip_h = (facing == -1)
	_collision_charge.disabled = true
	
	_player = get_tree().get_first_node_in_group("player")
	
	for area in get_tree().get_nodes_in_group("arena_limit"):
		area.body_entered.connect(_on_limit_body_entered)
	
	start_shoot_cycle()

func _process(delta):
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	if state == State.RECOVER:
		if _player == null:
			_player = get_tree().get_first_node_in_group("player")
			return
	match state:
		State.RECOVER:
			var direction = sign(_player.global_position.x - global_position.x)
			set_direction(direction)
			_animated_sprite.play("halt")
		State.SHOOT:
			_animated_sprite.play("shoot")
		State.CHARGE:
			_animated_sprite.play("run")

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	if state == State.CHARGE:
		velocity.x = charge_direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func start_shoot_cycle():
	shots_fired = 0
	shots_target = randi_range(3, 6)
	state = State.SHOOT
	
	damage_taken_in_shoot = 0
	
	print("VAI ATIRAR:", shots_target)

func fire():
	if state != State.SHOOT:
		return
	
	if shots_fired >= shots_target:
		return
	
	var bullet = Bullet.instantiate()
	_shot_sound.play()
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	
	get_tree().current_scene.add_child(bullet)
	
	shots_fired += 1
	print("TIROS:", shots_fired, "/", shots_target)
	
	if shots_fired >= shots_target:
		start_charge()

func start_charge():
	charge_count = 0
	
	await get_tree().create_timer(1).timeout
	print("START CHARGE")
	
	state = State.CHARGE
	
	if global_position.x < 200:
		charge_direction = 1
	else:
		charge_direction = -1
	
	set_direction(charge_direction)
	_collision_charge.disabled = false
	_collision_charge_area.monitoring = true

func end_charge():
	print("END CHARGE")
	
	_collision_charge.disabled = true
	_collision_charge_area.monitoring = false

	charge_count += 1
	
	if is_berserk and charge_count < max_charges:
		print("CHAIN CHARGE")
		start_charge()
		return
	
	velocity.x = 0
	state = State.RECOVER
	
	var recover_time = 1.0
	if is_berserk:
		recover_time = 0.5
	
	await get_tree().create_timer(recover_time).timeout
	
	start_shoot_cycle()

func set_direction(dir):
	if dir == 0 or facing == dir:
		return

	facing = dir
	
	_collision_charge.position.x *= -1
	_bullet_spawn.position.x *= -1
	_animated_sprite.flip_h = (dir == -1)

signal health_changed(new_health)

func take_damage(damage = 1):
	health -= damage
	health = max(health, 0)
	
	emit_signal("health_changed", health)
	
	if health <= 0:
		die()
		return
	
	if health <= 40 and not is_phase_two:
		is_phase_two = true
		print("fassssst")
		_fire_timer.wait_time = FAST_FIRE_RATE
	
	if health <= 15 and not is_berserk:
		is_berserk = true
		print("BERSERK!!!")
		
		max_charges = 3
	
	if state == State.SHOOT:
		damage_taken_in_shoot += damage
		print("DANO ACUMULADO: ", damage_taken_in_shoot)
		
		if damage_taken_in_shoot >= 15:
			print("CORREEEEE")
			start_charge()

signal died

func die():
	print("MORREU")

	state = State.RECOVER
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	
	# Usar set_deferred desliga a física com segurança sem causar erros na engine
	_collision_charge.set_deferred("disabled", true)
	_collision_charge_area.set_deferred("monitoring", false)
	
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	
	_animated_sprite.play("death")
	
	await get_tree().create_timer(1.5).timeout
	
	emit_signal("died")
	queue_free()

func _on_tf_fire_rate_timeout():
	if state != State.SHOOT:
		return
	fire()

func _on_limit_body_entered(body):
	if body != self:
		return

	if state == State.CHARGE:
		print("BATEU NO LIMITE")
		end_charge()

func _on_tf_charge_collision_body_entered(body: Node2D) -> void:
	# TRAVA DE SEGURANÇA: Se ele estiver morto, não causa mais dano nenhum!
	if health <= 0:
		return
		
	if body.is_invulnerable:
		return
	elif body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(20)
		if body.has_method("heavy_stun"):
			body.heavy_stun()
