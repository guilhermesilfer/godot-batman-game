extends CharacterBody2D

@onready var _animated_sprite = $BatmanAnimatedSprite2D
@onready var _collision_standing = $CollisionStanding
@onready var _collision_crouching1 = $CollisionCrouch1
@onready var _collision_crouching2 = $CollisionCrouch2
@onready var _area_punch = $CollisionHits
@onready var _collision_punching = $CollisionHits/CollisionPunch
@onready var _collision_kicking = $CollisionHits/CollisionKick
@onready var _right_puch_sound = $RightPunchSound
@onready var _left_puch_sound = $LeftPunchSound
@onready var _damage_sound1 = $DamageSound1
@onready var _damage_sound2 = $DamageSound2

const SPEED = 180.0
const JUMP_VELOCITY = -370.0
const MAX_HEALTH = 100

var is_dead := false
var is_stunned := false
var health = MAX_HEALTH
var is_crouching: bool
var is_punching := false
var is_kicking := false
var is_upping := false
var right_punch := false
var is_rolling := false
var is_invulnerable := false
var roll_speed := 250.0 
var roll_time := 0.7 
var facing := 1

func _ready() -> void:
	health = MAX_HEALTH
	add_to_group("player") 
	_animated_sprite.animation_finished.connect(_on_animation_finished)
	if _collision_kicking: _collision_kicking.disabled = true

func _physics_process(delta: float) -> void:
	if is_dead: return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return
	
	if is_rolling:
		velocity.x = facing * roll_speed
		move_and_slide()
		return

	var direction := 0.0
	if not is_rolling:
		direction = Input.get_axis("left", "right")
		
		# Lógica refinada para transição de agachamento e "upping"
		if not is_punching and not is_kicking and not is_upping:
			var wants_to_crouch = Input.is_action_pressed("crouch") and is_on_floor()
			
			if is_crouching and not wants_to_crouch:
				is_crouching = false
				upping()
			else:
				is_crouching = wants_to_crouch

		if direction != 0 and not is_upping:
			set_direction(direction)

	if is_crouching or is_punching or is_kicking or is_upping:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if Input.is_action_just_pressed("roll") and is_on_floor() and not is_rolling and not is_punching and not is_kicking and not is_upping:
		start_roll()

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_punching and not is_kicking and not is_rolling and not is_upping:
		velocity.y = JUMP_VELOCITY

	# Lógica de Hitboxes
	_collision_standing.disabled = is_crouching
	_collision_crouching1.disabled = not is_crouching
	_collision_crouching2.disabled = not is_crouching
	
	if is_punching and (_animated_sprite.animation == "right punch" or _animated_sprite.animation == "left punch"):
		_collision_punching.disabled = _animated_sprite.frame != 1
		if _collision_kicking: _collision_kicking.disabled = true
	elif is_kicking and _animated_sprite.animation == "kick":
		if _collision_punching: _collision_punching.disabled = true
		if _collision_kicking: _collision_kicking.disabled = _animated_sprite.frame != 2
	else:
		if _collision_punching: _collision_punching.disabled = true
		if _collision_kicking: _collision_kicking.disabled = true

	move_and_slide()

func _process(_delta):
	if is_dead:
		return
	elif is_stunned:
		return
	elif is_rolling:
		return
	elif is_punching or is_kicking or is_upping:
		pass 
	elif is_crouching:
		play_anim("crouch")
	elif Input.is_action_just_pressed("roll") and is_on_floor() and not is_punching and not is_kicking and not is_upping:
		play_anim("roll")
	elif not is_on_floor():
		play_anim("jump")
	elif velocity.x != 0:
		play_anim("run")
	else:
		play_anim("halt")
	
	# Ataques
	if Input.is_action_just_pressed("fire") and is_on_floor() and not is_punching and not is_kicking and not is_rolling and not is_upping:
		if is_crouching:
			kick()
		else:
			punch()

func upping():
	is_upping = true
	_animated_sprite.play("upping")

func punch():
	is_punching = true
	if right_punch:
		_animated_sprite.play("right punch")
	else:
		_animated_sprite.play("left punch")
	right_punch = !right_punch

func kick():
	is_kicking = true
	_animated_sprite.play("kick")

func _on_animation_finished():
	if is_punching and (_animated_sprite.animation == "right punch" or _animated_sprite.animation == "left punch"):
		is_punching = false
	elif is_kicking and _animated_sprite.animation == "kick":
		is_kicking = false
		if is_crouching:
			_animated_sprite.play("crouch")
			_animated_sprite.frame = 4
	elif is_rolling and _animated_sprite.animation == "roll":
		is_rolling = false
		is_invulnerable = false
	elif is_upping and _animated_sprite.animation == "upping":
		is_upping = false

func play_anim(anim_name):
	if _animated_sprite.animation != anim_name:
		_animated_sprite.play(anim_name)

func set_direction(dir):
	if facing == dir:
		return
	
	facing = dir
	
	_collision_crouching1.position.x *= -1
	_collision_crouching2.position.x *= -1
	_collision_standing.position.x *= -1
	
	if _area_punch:
		_area_punch.position.x = abs(_area_punch.position.x) * dir
	if _collision_punching:
		_collision_punching.position.x = abs(_collision_punching.position.x) * dir
	if _collision_kicking:
		_collision_kicking.position.x = abs(_collision_kicking.position.x) * dir
	
	_animated_sprite.flip_h = (dir == -1)

func start_roll():
	is_rolling = true
	is_invulnerable = true
	_animated_sprite.play("roll")

signal health_changed(new_health)

func take_damage(damage = 1):
	if is_invulnerable or is_dead:
		return
	
	health -= damage
	health = max(health, 0)
	
	emit_signal("health_changed", health)
	if randi() % 2 == 0:
		_damage_sound1.play()
	else:
		_damage_sound2.play()
	
	if health <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true
	is_invulnerable = true
	
	is_stunned = true
	velocity = Vector2.ZERO
	
	_animated_sprite.stop()
	_animated_sprite.play("death")
	
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func stun():
	if is_invulnerable or is_dead:
		return
	
	is_stunned = true
	is_punching = false
	is_kicking = false
	is_rolling = false
	is_upping = false
	
	velocity = Vector2.ZERO
	
	play_anim("stun")
	
	await get_tree().create_timer(0.4).timeout
	
	is_stunned = false

func heavy_stun():
	if is_invulnerable or is_dead:
		return
	
	is_stunned = true
	is_punching = false
	is_kicking = false
	is_rolling = false
	is_upping = false
	
	velocity = Vector2.ZERO
	
	play_anim("heavy stun")
	
	await get_tree().create_timer(2).timeout
	
	is_stunned = false

func _on_collision_punch_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			if right_punch:
				_right_puch_sound.play()
			else:
				_left_puch_sound.play()
			body.take_damage()
