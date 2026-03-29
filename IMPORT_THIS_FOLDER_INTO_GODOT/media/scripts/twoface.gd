extends CharacterBody2D

enum State {
	SHOOT,
	DASH,
	RECOVER
}

var Bullet = preload("res://media/scenes/projectile.tscn")

var facing := -1
var state = State.SHOOT
var dash_direction = 1
var shots_fired = 0
var shots_target = 0
var can_shoot := false

var _player: Node2D

@onready var _bullet_spawn = $TFBulletSpawn
@onready var _animated_sprite = $TFAnimatedSprite2D
@onready var _collision_charge = $TFChargeCollision/CollisionShape2D
@onready var _fire_timer = $TFFireRate

const SPEED = 220.0

func _ready():
	_bullet_spawn.position.x *= facing
	_collision_charge.position.x *= facing
	_animated_sprite.flip_h = (facing == -1)

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
			if can_shoot:
				fire()
				_animated_sprite.play("shoot")
		State.DASH:
			_animated_sprite.play("run")

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	if state == State.DASH:
		velocity.x = dash_direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func start_shoot_cycle():
	shots_fired = 0
	shots_target = randi_range(3, 6)
	can_shoot = true
	state = State.SHOOT
	
	print("VAI ATIRAR:", shots_target)

func fire():
	can_shoot = false
	
	var bullet = Bullet.instantiate()
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	
	get_tree().current_scene.add_child(bullet)
	
	shots_fired += 1
	print("TIROS:", shots_fired, "/", shots_target)
	
	if shots_fired >= shots_target:
		start_dash()

func start_dash():
	print("START DASH")
	
	state = State.DASH
	
	if global_position.x < 200:
		dash_direction = 1
	else:
		dash_direction = -1
	
	set_direction(dash_direction)

func end_dash():
	print("END DASH")
	velocity.x = 0
	state = State.RECOVER
	
	await get_tree().create_timer(1.0).timeout
	
	start_shoot_cycle()

func set_direction(dir):
	if dir == 0 or facing == dir:
		return

	facing = dir
	
	_collision_charge.position.x *= -1
	_bullet_spawn.position.x *= -1
	_animated_sprite.flip_h = (dir == -1)

func _on_tf_fire_rate_timeout():
	can_shoot = true

func _on_limit_body_entered(body):
	if body != self:
		return

	if state == State.DASH:
		print("BATEU NO LIMITE")
		end_dash()


func _on_tf_charge_collision_body_entered(body: Node2D) -> void:
	if body.is_invulnerable:
		return
	elif body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(30)
		if body.has_method("stun"):
			body.stun()
	queue_free()
