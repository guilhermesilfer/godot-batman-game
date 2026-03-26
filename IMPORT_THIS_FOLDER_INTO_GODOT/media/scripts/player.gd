extends CharacterBody2D

var Bullet = preload("res://media/scenes/projectile.tscn")

@onready var _bullet_spawn = $BulletSpawn
@onready var _animated_sprite = $AnimatedSprite2D
@onready var _collision_standing = $CollisionStanding
@onready var _collision_crouching1 = $CollisionCrouch1
@onready var _collision_crouching2 = $CollisionCrouch2

var is_crouching: bool
var is_rolling := false
var is_invulnerable := false
var roll_speed := 300.0
var roll_time := 0.4
var facing := 1

const SPEED = 180.0
const JUMP_VELOCITY = -370.0

func _physics_process(delta: float) -> void:
	if is_rolling:
		velocity.x = facing * roll_speed
		move_and_slide()
		return
	
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# input
	var direction := Input.get_axis("left", "right")
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()

	if direction != 0:
		set_direction(direction)

	# horizontal movement
	if is_crouching:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if Input.is_action_just_pressed("roll") and is_on_floor() and not is_rolling:
		start_roll()

	# vertical movement
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	# collisions
	_collision_standing.disabled = is_crouching
	_collision_crouching1.disabled = not is_crouching
	_collision_crouching2.disabled = not is_crouching

	move_and_slide()


func _process(_delta):
	if is_rolling:
		return
	elif is_crouching:
		play_anim("crouch")
	elif Input.is_action_pressed("roll") and is_on_floor():
		play_anim("roll")
	elif not is_on_floor():
		play_anim("jump") # se não tiver, pode remover
	elif velocity.x != 0:
		play_anim("run")
	else:
		play_anim("halt")

	# Tiro
	if Input.is_action_just_pressed("fire"):
		fire()


func play_anim(name):
	if _animated_sprite.animation != name:
		_animated_sprite.play(name)


func set_direction(dir):
	if facing == dir:
		return
	
	facing = dir
	
	_collision_crouching1.position.x *= -1
	_collision_crouching2.position.x *= -1
	_collision_standing.position.x *= -1
	_bullet_spawn.position.x *= -1
	
	_animated_sprite.flip_h = (dir == -1)

func start_roll():
	is_rolling = true
	is_invulnerable = true
	
	# toca animação 1 vez
	_animated_sprite.play("roll")
	
	# espera o tempo do roll
	await get_tree().create_timer(roll_time).timeout
	
	is_rolling = false
	is_invulnerable = false

func fire():
	var bullet = Bullet.instantiate()
	
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	
	get_tree().current_scene.add_child(bullet)

func take_damage():
	if is_invulnerable:
		return
