extends CharacterBody2D

# Sistema de estados adaptado para incluir preparação e investida
enum State {
	SHOOT,
	LOAD,    # Estado onde ele fica parado e vermelho
	CHARGE,  # Investida com zigue-zague
	RECOVER,
	DEAD
}

const SPEED = 220.0
const MAX_HEALTH = 60
const NORMAL_FIRE_RATE = 1.0
const FAST_FIRE_RATE = 0.4
const LEFT_WALL = 45.0   # Limites de arena baseados no Bane
const RIGHT_WALL = 275.0

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
@onready var _twoface_laugh_sound = $TwofaceLaugh
@onready var _twoface_death_sound = $TwofaceDeath
@onready var _voice_lines = [$TwofaceVa1, $TwofaceVa2, $TwofaceVa3, $TwofaceVa4]

# --- NOVAS VARIÁVEIS DO SISTEMA DE ÁUDIO ---
var _voice_bag : Array[int] = []
var _audio_queue : Array[String] = []
var _audio_sequence_active := false
var _passive_voice_timer := 0.0

signal health_changed(new_health)
signal died

func _ready():
	_fire_timer.wait_time = NORMAL_FIRE_RATE
	health = MAX_HEALTH
	_bullet_spawn.position.x *= facing
	_collision_charge.position.x *= facing
	_animated_sprite.flip_h = (facing == -1)
	_collision_charge.disabled = true
	
	_player = get_tree().get_first_node_in_group("player")
	
	_refill_voice_bag()
	_passive_voice_timer = randf_range(8.0, 10.0)
	
	start_shoot_cycle()

func _physics_process(delta):
	if state == State.DEAD: return

	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.CHARGE:
			velocity.x = charge_direction * SPEED
			check_walls() # Lógica de zigue-zague
		State.LOAD, State.RECOVER, State.SHOOT:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	# Cronômetro passivo para as falas
	_passive_voice_timer -= delta
	if _passive_voice_timer <= 0:
		_queue_audio("voice")
		_passive_voice_timer = randf_range(8.0, 10.0)

func _process(_delta):
	if state == State.DEAD: return
	
	# Busca o player se a referência estiver vazia ou se o objeto foi deletado
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	
	match state:
		State.LOAD, State.RECOVER:
			var direction = sign(_player.global_position.x - global_position.x)
			set_direction(direction)
			_animated_sprite.play("halt")
		State.SHOOT:
			_animated_sprite.play("shoot")
		State.CHARGE:
			_animated_sprite.play("run")

# --- LÓGICA DE MOVIMENTO EM ZIGUE-ZAGUE ---
func check_walls():
	if global_position.x <= LEFT_WALL and charge_direction == -1:
		bounce()
	elif global_position.x >= RIGHT_WALL and charge_direction == 1:
		bounce()

func bounce():
	charge_count += 1
	if charge_count >= max_charges:
		end_charge()
	else:
		charge_direction *= -1
		set_direction(charge_direction)

# --- CICLO DE ATAQUE ---
func start_shoot_cycle():
	shots_fired = 0
	shots_target = randi_range(3, 6)
	state = State.SHOOT
	damage_taken_in_shoot = 0

func fire():
	if state != State.SHOOT or shots_fired >= shots_target: return
	
	var bullet = Bullet.instantiate()
	_shot_sound.play()
	bullet.global_position = _bullet_spawn.global_position
	bullet.speed = abs(bullet.speed) * facing
	get_tree().current_scene.add_child(bullet)
	
	shots_fired += 1
	if shots_fired >= shots_target:
		prepare_charge()

# --- SISTEMA DE CARGA COM AVISO VERMELHO ---
func prepare_charge():
	state = State.LOAD
	
	var tween = create_tween()
	tween.tween_property(_animated_sprite, "modulate", Color.RED, 0.5)
	
	await get_tree().create_timer(1.0).timeout
	
	_animated_sprite.modulate = Color.WHITE
	if state == State.DEAD: return
	
	start_charge()

func start_charge():
	state = State.CHARGE
	charge_count = 0
	charge_direction = 1 if global_position.x < 160 else -1
	set_direction(charge_direction)
	
	_collision_charge.disabled = false
	_collision_charge_area.monitoring = true

func end_charge():
	_collision_charge.disabled = true
	_collision_charge_area.monitoring = false
	velocity.x = 0
	state = State.RECOVER
	
	var recover_time = 0.5 if is_berserk else 1.0
	await get_tree().create_timer(recover_time).timeout
	
	if state != State.DEAD:
		start_shoot_cycle()

# --- UTILITÁRIOS ---
func set_direction(dir):
	if dir == 0 or facing == dir: return
	facing = dir
	_collision_charge.position.x = abs(_collision_charge.position.x) * dir
	_bullet_spawn.position.x = abs(_bullet_spawn.position.x) * dir
	_animated_sprite.flip_h = (dir == -1)

func take_damage(damage = 6):
	if state == State.DEAD: return
	
	var tween = create_tween()
	_animated_sprite.modulate = Color(10, 10, 10)
	tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.15)
	
	health = max(health - damage, 0)
	emit_signal("health_changed", health)
	
	if health <= 0:
		die()
		return
	
	if health <= 40 and not is_phase_two:
		is_phase_two = true
		_fire_timer.wait_time = FAST_FIRE_RATE
	
	if health <= 15 and not is_berserk:
		is_berserk = true
		max_charges = 3
	
	if state == State.SHOOT:
		damage_taken_in_shoot += damage
		if damage_taken_in_shoot >= 15:
			prepare_charge()

func die():
	state = State.DEAD
	velocity = Vector2.ZERO
	_animated_sprite.modulate = Color.WHITE
	_collision_charge.set_deferred("disabled", true)
	_collision_charge_area.set_deferred("monitoring", false)
	
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
			
	# --- SILENCIA TUDO E TOCA O SOM DE MORTE ---
	_shot_sound.stop()
	_twoface_laugh_sound.stop()
	for voice in _voice_lines:
		if voice.playing:
			voice.stop()
	_audio_queue.clear()
	_audio_sequence_active = false
	if _twoface_death_sound:
		_twoface_death_sound.play()
	
	_animated_sprite.play("death")
	await get_tree().create_timer(1.5).timeout
	emit_signal("died")
	queue_free()

func _on_tf_fire_rate_timeout():
	if state == State.SHOOT:
		fire()

func _on_tf_charge_collision_body_entered(body: Node2D) -> void:
	if state == State.DEAD: return
	
	if body.is_in_group("player"):
		if body.is_invulnerable or body.is_dead:
			return
			
		if body.has_method("take_damage"):
			body.take_damage(15)
			_queue_audio("laugh")
			
		if body.has_method("heavy_stun"):
			body.heavy_stun()

# --- SISTEMA DE FILA DE ÁUDIO E SHUFFLE BAG ---
func _refill_voice_bag():
	_voice_bag.clear()
	for i in range(_voice_lines.size()):
		_voice_bag.append(i)
	_voice_bag.shuffle()

func _queue_audio(audio_type: String):
	_audio_queue.append(audio_type)
	if not _audio_sequence_active:
		_process_audio_queue()

func _process_audio_queue():
	if _audio_queue.is_empty() or state == State.DEAD:
		_audio_sequence_active = false
		return
		
	_audio_sequence_active = true
	var next_audio = _audio_queue.pop_front()
	
	if next_audio == "laugh":
		_twoface_laugh_sound.play()
		await _twoface_laugh_sound.finished
	elif next_audio == "voice":
		if _voice_bag.is_empty():
			_refill_voice_bag()
		var idx = _voice_bag.pop_back()
		var voice_node = _voice_lines[idx]
		voice_node.play()
		await voice_node.finished
		
	_process_audio_queue()
