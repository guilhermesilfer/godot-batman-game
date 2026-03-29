extends CharacterBody2D

var Bullet = preload("res://media/scenes/projectile.tscn")

@onready var _bullet_spawn = $BulletSpawn
@onready var _animated_sprite = $BatmanAnimatedSprite2D
@onready var _collision_standing = $CollisionStanding
@onready var _collision_crouching1 = $CollisionCrouch1
@onready var _collision_crouching2 = $CollisionCrouch2
@onready var _area_punch = $CollisionPunch
@onready var _collision_punching = $CollisionPunch/CollisionShape2D

const SPEED = 180.0
const JUMP_VELOCITY = -370.0
const MAX_HEALTH = 100

var health = MAX_HEALTH
var is_crouching: bool
var is_punching := false
var right_punch := false
var is_rolling := false
var is_invulnerable := false
var roll_speed := 250.0 
var roll_time := 0.7 
var facing := 1

signal health_changed(new_health)

func _ready() -> void:
	health = MAX_HEALTH
	add_to_group("player") 
	_animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if is_rolling:
		velocity.x = facing * roll_speed
		move_and_slide()
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- CORREÇÃO: Bloqueia leitura de inputs de movimento e direção durante o soco ---
	var direction := 0.0
	if not is_punching and not is_rolling:
		direction = Input.get_axis("left", "right")
		is_crouching = Input.is_action_pressed("crouch") and is_on_floor()

		if direction != 0:
			set_direction(direction)

	if is_crouching or is_punching:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if Input.is_action_just_pressed("roll") and is_on_floor() and not is_rolling and not is_punching:
		start_roll()

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_punching and not is_rolling:
		velocity.y = JUMP_VELOCITY

	_collision_standing.disabled = is_crouching
	_collision_crouching1.disabled = not is_crouching
	_collision_crouching2.disabled = not is_crouching
	
	if is_punching and (_animated_sprite.animation == "right punch" or _animated_sprite.animation == "left punch"):
		_collision_punching.disabled = _animated_sprite.frame != 1
	else:
		_collision_punching.disabled = true

	move_and_slide()

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		var player = get_tree().get_first_node_in_group("player")
		print("player encontrado:", player)
		if player:
			player.take_damage(10)
	
	if is_rolling:
		return
	elif is_punching:
		pass 
	elif is_crouching:
		play_anim("crouch")
	elif Input.is_action_just_pressed("roll") and is_on_floor() and not is_punching:
		play_anim("roll")
	elif not is_on_floor():
		play_anim("jump")
	elif velocity.x != 0:
		_animated_sprite.position.x = -10 * facing 
		play_anim("run")
	else:
		play_anim("halt")

	if Input.is_action_just_pressed("fire") and is_on_floor() and not is_crouching and not is_punching and not is_rolling:
		punch()

func punch():
	is_punching = true
	
	if right_punch:
		_animated_sprite.position.x = 10 * facing
		_animated_sprite.play("right punch")
	else:
		_animated_sprite.position.x = 10 * facing
		_animated_sprite.play("left punch")
		
	right_punch = !right_punch
	
	var fallback_timer = get_tree().create_timer(0.4) 
	fallback_timer.timeout.connect(func():
		if is_punching:
			is_punching = false
			print("Fallback de soco stuck acionado (animação em loop?). Batman liberado.")
	)

func _on_animation_finished():
	if is_punching and (_animated_sprite.animation == "right punch" or _animated_sprite.animation == "left punch"):
		is_punching = false

func play_anim(name):
	if _animated_sprite.animation != name:
		_animated_sprite.position.x = 0 
		_animated_sprite.play(name)

func set_direction(dir):
	if facing == dir:
		return
	
	facing = dir
	
	_collision_crouching1.position.x *= -1
	_collision_crouching2.position.x *= -1
	_collision_standing.position.x *= -1
	if _bullet_spawn: 
		_bullet_spawn.position.x *= -1
	if _area_punch:
		_area_punch.position.x = abs(_area_punch.position.x) * dir
	if _collision_punching:
		_collision_punching.position.x = abs(_collision_punching.position.x) * dir
	
	_animated_sprite.flip_h = (dir == -1)

func start_roll():
	is_rolling = true
	is_invulnerable = true
	
	_animated_sprite.play("roll")
	
	await get_tree().create_timer(roll_time).timeout
	
	is_rolling = false
	is_invulnerable = false

func fire():
	var bullet = Bullet.instantiate()
	
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	
	get_tree().current_scene.add_child(bullet)

func take_damage(damage = 1):
	if is_invulnerable:
		return
	
	health -= damage
	health = max(health, 0)
	
	emit_signal("health_changed", health)
