extends CharacterBody2D

enum State {
	SHOOT,
	VINES,
	DESCEND,
	MOVE,
	EMERGE,
	DEAD
}

const MAX_HEALTH = 60
const ESCAPE_DISTANCE = 80.0 

const MIN_X = 16
const MAX_X = 304
const ESCAPE_DELAY = 0.5

var Bullet = preload("res://media/scenes/ivy_projectile.tscn")
var Vine = preload("res://media/scenes/vines.tscn")

var _escape_timer := 0.0
var facing := -1
var state = State.SHOOT
var health = MAX_HEALTH
var shots_fired = 0
var shots_target = 0

var _player: Node2D

@onready var _animated_sprite = $IvyAnimatedSprite2D
@onready var _bullet_spawn = $IvyBulletSpawn
@onready var _collision = $IvyCollision
@onready var _laugh_sound = $LaughSound
@onready var _shot_sound = $ShotSound

var _spawn_base_x := 0.0

signal health_changed(new_health)
signal died

# -------------------------
# SETUP
# -------------------------

func _ready():
	health = MAX_HEALTH
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_changed.connect(_on_player_health_changed)
	_spawn_base_x = _bullet_spawn.position.x
	start_shoot_cycle()

func _physics_process(delta):
	if state == State.DEAD: return
	
	if state == State.SHOOT or state == State.VINES:
		await get_tree().create_timer(2.0)
		if player_is_close():
			start_descend()
	
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	
	update_facing()
	
	if state == State.MOVE:
		velocity = Vector2.ZERO
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()

# -------------------------
# COMBATE
# -------------------------

func start_shoot_cycle():
	if state == State.DEAD: return
	state = State.SHOOT
	shots_fired = 0
	shots_target = randi_range(2, 2)
	play_shoot()

func play_shoot():
	if state == State.SHOOT:
		_animated_sprite.play("shoot")

func player_is_close() -> bool:
	if _player == null: return false
	
	var is_near = abs(_player.global_position.x - global_position.x) <= ESCAPE_DISTANCE
	
	if is_near:
		_escape_timer += get_physics_process_delta_time()
		return _escape_timer >= ESCAPE_DELAY
	else:
		_escape_timer = 0.0
		return false

func fire():
	if state != State.SHOOT or _player == null: return
	
	var bullet = Bullet.instantiate()
	_shot_sound.play()
	bullet.global_position = _bullet_spawn.global_position
	var dir = sign(_player.global_position.x - global_position.x)
	bullet.scale.x = dir
	get_tree().current_scene.add_child(bullet)
	shots_fired += 1

func spawn_vine_at_position(pos: Vector2):
	var vine = Vine.instantiate()
	vine.global_position = pos
	get_tree().current_scene.add_child(vine)

func attack_vines_player():
	if _player == null: return
	state = State.VINES
	
	var spawn_pos = Vector2(_player.global_position.x, global_position.y)
	print(spawn_pos)
	
	spawn_vine_at_position(spawn_pos)
	
	await get_tree().create_timer(1.2).timeout
	start_shoot_cycle()

func spawn_vine_front():
	var offset = 40 * -facing
	var spawn_pos = Vector2(global_position.x + offset, global_position.y)
	print(spawn_pos)
	spawn_vine_at_position(spawn_pos)

# -------------------------
# BURROW SYSTEM (Toca)
# -------------------------

func start_descend():
	if state == State.DEAD: return
	
	_escape_timer = 0.0
	
	state = State.DESCEND
	_animated_sprite.play("descend")
	await _animated_sprite.animation_finished
	_collision.set_deferred("disabled", true)
	start_move()

func start_move():
	state = State.MOVE
	var new_x = get_safe_position()
	global_position.x = new_x # Move apenas no X
	await get_tree().create_timer(0.4).timeout
	start_emerge()

func start_emerge():
	state = State.EMERGE
	_animated_sprite.play("ascend")
	_collision.set_deferred("disabled", false)
	await _animated_sprite.animation_finished
	spawn_vine_front()
	start_shoot_cycle()

# -------------------------
# DIREÇÃO E VIDA
# -------------------------

func update_facing():
	if _player == null or state == State.DESCEND or state == State.EMERGE: return
	var dir = sign(global_position.x - _player.global_position.x)
	if dir != 0 and dir != facing:
		facing = dir
		_animated_sprite.flip_h = (facing == -1)
		_bullet_spawn.position.x = _spawn_base_x * facing

func get_safe_position() -> float:
	if _player == null: return randf_range(MIN_X, MAX_X)
	var player_x = _player.global_position.x
	var mid = (MIN_X + MAX_X) / 2.0
	return randf_range(mid + 80, MAX_X) if player_x < mid else randf_range(MIN_X, mid - 80)

func _on_ivy_animated_sprite_2d_frame_changed():
	if state == State.SHOOT and _animated_sprite.animation == "shoot":
		if _animated_sprite.frame == 4:
			fire()

func _on_ivy_animated_sprite_2d_animation_finished():
	if state != State.SHOOT: return
	
	if shots_fired < shots_target:
		play_shoot()
		return
	
	if player_is_close():
		await get_tree().create_timer(1.2).timeout
		start_descend()
		return
	var chance = randf()
	if chance <= 0.4:
		attack_vines_player()
	else:
		start_shoot_cycle()

func take_damage(damage = 1):
	if state == State.MOVE or state == State.DESCEND: return
	
	var tween = create_tween()
	_animated_sprite.modulate = Color(10, 10, 10)
	tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.15)
	
	health = max(health - damage, 0)
	emit_signal("health_changed", health)
	if health <= 0: die()

func die():
	state = State.DEAD
	_collision.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_animated_sprite.play("death")
	await get_tree().create_timer(1.5).timeout
	emit_signal("died")
	queue_free()

func _on_player_health_changed(new_health):
	if state != State.DEAD and not _laugh_sound.playing:
		_laugh_sound.play()
