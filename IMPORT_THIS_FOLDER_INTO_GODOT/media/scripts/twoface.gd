extends CharacterBody2D

var Bullet = preload("res://media/scenes/projectile.tscn")

var facing := 1
var is_invulnerable := false

@onready var _bullet_spawn = $TFBulletSpawn
@onready var _animated_sprite = $TFAnimatedSprite2D
@onready var _collision_charge = $TFChargeCollision/CollisionShape2D
var _player: Node2D

const SPEED = 600.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _process(delta: float) -> void:
	# checks if batman if left or right of two face and sets looking direction
	var direction = sign(_player.global_position.x - global_position.x)
	set_direction(direction)
	fire()

func set_direction(dir):
	if facing == dir:
		return
	
	facing = dir
	
	_collision_charge.position.x *= -1
	_bullet_spawn.position.x *= -1
	
	_animated_sprite.flip_h = (dir == -1)

func fire():
	var bullet = Bullet.instantiate()
	
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	
	get_tree().current_scene.add_child(bullet)
