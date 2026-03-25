extends CharacterBody2D

@onready var _animated_sprite = $AnimatedSprite2D
# Pegamos referências aos nossos novos nós de colisão renomeados
@onready var _collision_standing = $CollisionStanding
@onready var _collision_crouching1 = $CollisionCrouch1
@onready var _collision_crouching2 = $CollisionCrouch2

const SPEED = 180.0
const JUMP_VELOCITY = -370.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_pressed("crouch") and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		# --- NOVO: Lógica de Hitbox Agachada ---
		# Desativar colisão em pé, ativar colisão agachado
		_collision_standing.disabled = true
		_collision_crouching1.disabled = false
		_collision_crouching2.disabled = false
		# ---
	else:
		# --- NOVO: Lógica de Hitbox Levantada (Padrão) ---
		# Reverter colisões
		_collision_standing.disabled = false
		_collision_crouching1.disabled = true
		_collision_crouching2.disabled = true
		# ---

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
	if Input.is_action_pressed("crouch") and is_on_floor():
		if _animated_sprite.frame >= 0: _animated_sprite.position.y = 2
		if _animated_sprite.frame >= 1: _animated_sprite.position.y = 8
		if _animated_sprite.frame >= 2: _animated_sprite.position.y = 7
		if _animated_sprite.frame >= 3: _animated_sprite.position.y = 11
		if _animated_sprite.frame >= 4: _animated_sprite.position.y = 11
		if _animated_sprite.animation != "crouch":
			_animated_sprite.play("crouch")
			
	elif Input.is_action_pressed("left") and Input.is_action_pressed("right"):
		_animated_sprite.position.y = 0.0
		_animated_sprite.play("idle")
	elif Input.is_action_pressed("left"):
		_collision_crouching1.position.x = -abs(_collision_crouching1.position.x)
		_collision_crouching2.position.x = -abs(_collision_crouching2.position.x)
		_collision_standing.position.x = -abs(_collision_standing.position.x)
		_animated_sprite.position.y = 0.0
		_animated_sprite.flip_h = true
		_animated_sprite.play("run")
	elif Input.is_action_pressed("right"):
		_collision_crouching1.position.x = abs(_collision_crouching1.position.x)
		_collision_crouching2.position.x = abs(_collision_crouching2.position.x)
		_collision_standing.position.x = abs(_collision_standing.position.x)
		_animated_sprite.position.y = 0.0
		_animated_sprite.flip_h = false
		_animated_sprite.play("run")
			
	# Rool implementation
	elif Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		_animated_sprite.play("roll")

	else:
		_animated_sprite.position.y = 0.0
		_animated_sprite.play("idle")
		
		# --- NOVO: Resetar a posição da sprite ao levantar ---
		_animated_sprite.position.y = 0.0
		# ---
