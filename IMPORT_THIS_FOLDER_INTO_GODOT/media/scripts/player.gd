extends CharacterBody2D

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

	move_and_slide()

func _process(_delta):
	# batman movement logic
	if Input.is_action_pressed("left") and Input.is_action_pressed("right"):
		_animated_sprite.play("idle")
	elif Input.is_action_pressed("left"):
		_animated_sprite.flip_h = true
		_animated_sprite.play("run")
	elif Input.is_action_pressed("right"):
		_animated_sprite.flip_h = false
		_animated_sprite.play("run")
	else:
		_animated_sprite.play("idle")
		
