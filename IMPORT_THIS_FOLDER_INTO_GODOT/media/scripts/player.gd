extends CharacterBody2D
var Bullet = preload("res://media/scenes/projectile.tscn")
@onready var _animated_sprite = $AnimatedSprite2D

const SPEED = 180.0
const JUMP_VELOCITY = -370.0


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	if Input.is_action_just_pressed("ui_accept"):
		var speed: int
		if $Node2D.position.x > 0:
			speed = 150
		if $Node2D.position.x < 0:
			speed = -150
		fire(speed)

	move_and_slide()

func _process(_delta):
	# batman movement logic
	if Input.is_action_pressed("left") and Input.is_action_pressed("right"):
		_animated_sprite.play("idle")
		_animated_sprite.offset = Vector2(0, 0) # resets sprite position
	elif Input.is_action_pressed("left"):
		_animated_sprite.flip_h = true
		_animated_sprite.play("run")
		_animated_sprite.offset = Vector2(15, 0) # adjust sprite offset for running
		$Node2D.position.x = -24
	elif Input.is_action_pressed("right"):
		_animated_sprite.flip_h = false
		_animated_sprite.play("run")
		_animated_sprite.offset = Vector2(-15, 0) # adjust sprite offset for running
		$Node2D.position.x = 24
	else:
		_animated_sprite.play("idle")
		_animated_sprite.offset = Vector2(0, 0) # resets sprite position
		

func fire(speed: int):
	var bullet = Bullet.instantiate()
	bullet.speed = speed
	bullet.dir = rotation
	bullet.pos = $Node2D.global_position
	get_parent().add_child(bullet)
