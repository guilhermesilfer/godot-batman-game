extends CharacterBody2D

# 1. Adicionamos o estado LAUGH aqui
enum State { IDLE, THROW, DROP_BOMB, JETPACK_TAKEOFF, JETPACK_CHARGE, JETPACK_LANDING, DAMAGE, DEAD, LAUGH }

const SPEED = 0.0 
const JETPACK_SPEED = 150.0 
const MAX_HEALTH = 100
const JETPACK_HEIGHT = 0.0 
const DAMAGE_THRESHOLD_FOR_JETPACK = 15 
const SCREEN_WIDTH_HALF = 160

var bombs_per_series = 3

var health = MAX_HEALTH
var state = State.IDLE
var facing = -1 
var start_y = 0.0 
var charge_direction = -1
var bomb_spawn_timer = 0.0
var damage_accumulated = 0 

var BouncingBomb = preload("res://media/scenes/bouncing_bomb.tscn")
var ParachuteBomb = preload("res://media/scenes/parachute_bomb.tscn")

var _player: Node2D

@onready var _animated_sprite = $JokerAnimatedSprite
@onready var _throw_spawn = $ThrowSpawn
@onready var _collision = $JokerCollision
@onready var _jetpack_hitbox = $JetpackHitbox
@onready var _jetpack_col = $JetpackHitbox/CollisionShape2D

# Referências para os áudios que vi na sua print
@onready var _laugh_sound1 = $JokerLaugh1
@onready var _laugh_sound2 = $JokerLaugh2

signal health_changed(new_health)
signal died

func _ready():
	health = MAX_HEALTH
	_jetpack_col.disabled = true
	_jetpack_hitbox.monitoring = false
	start_y = global_position.y
	_player = get_tree().get_first_node_in_group("player")
	
	# Garante que a risada toque inteira uma vez e pare
	if _animated_sprite.sprite_frames.has_animation("laugh"):
		_animated_sprite.sprite_frames.set_animation_loop("laugh", false)
	
	_animated_sprite.frame_changed.connect(_on_frame_changed)
	
	var limits = get_tree().get_nodes_in_group("arena_limit")
	for area in limits:
		if area is Area2D:
			if not area.body_entered.is_connected(_on_limit_body_entered):
				area.body_entered.connect(_on_limit_body_entered)
			
	if not _jetpack_hitbox.body_entered.is_connected(_on_jetpack_hitbox_body_entered):
		_jetpack_hitbox.body_entered.connect(_on_jetpack_hitbox_body_entered)
	
	start_parachute_timer()
	start_cycle()

func _physics_process(delta):
	if state == State.DEAD: return
	if _player == null: _player = get_tree().get_first_node_in_group("player")
	
	if state != State.JETPACK_TAKEOFF and state != State.JETPACK_CHARGE:
		if not is_on_floor():
			velocity += get_gravity() * delta
	else:
		velocity.y = 0
	
	match state:
		# 2. Adicionamos o State.LAUGH para ele ficar paradinho e virado para o player enquanto ri
		State.IDLE, State.THROW, State.JETPACK_LANDING, State.LAUGH:
			velocity.x = 0
			update_facing()
		
		State.JETPACK_TAKEOFF:
			global_position.y = move_toward(global_position.y, start_y + JETPACK_HEIGHT, 4.0)
		
		State.JETPACK_CHARGE:
			velocity.x = charge_direction * JETPACK_SPEED
	
	move_and_slide()

# -------------------------
# IA E COMBATE
# -------------------------

func start_parachute_timer():
	while true:
		await get_tree().create_timer(2.0).timeout
		if state == State.DEAD: break
		
		if randf() < 0.5:
			spawn_auto_parachute_bomb()

func start_cycle():
	if state == State.DEAD: return
	state = State.IDLE
	_animated_sprite.play("idle")
	
	await get_tree().create_timer(0.5).timeout 
	if state != State.IDLE: return
	
	var chance = randf()
	
	if chance < 0.20: 
		start_jetpack_init()
	else: 
		start_throw_series()

func start_throw_series():
	if state == State.DEAD: return
	
	for i in range(bombs_per_series):
		if state == State.DEAD or state == State.JETPACK_TAKEOFF: break
		
		state = State.THROW
		_animated_sprite.play("throw")
		
		await _animated_sprite.animation_finished
		
		if state == State.DEAD or state == State.JETPACK_TAKEOFF: break
		
		if i < bombs_per_series - 1:
			state = State.IDLE
			_animated_sprite.play("idle")
			await get_tree().create_timer(0.4).timeout
	
	if state != State.DEAD and state != State.JETPACK_TAKEOFF:
		# 3. A mágica acontece aqui: ao invés de voltar pro ciclo, ele começa a rir!
		start_laugh()

# 4. Nova função de Risada Invulnerável
func start_laugh():
	if state == State.DEAD or state == State.JETPACK_TAKEOFF: return
	
	state = State.LAUGH
	_animated_sprite.play("laugh")
	
	# Sorteia um dos dois áudios de risada
	if _laugh_sound1 and _laugh_sound2:
		if randi() % 2 == 0:
			_laugh_sound1.play()
		else:
			_laugh_sound2.play()
	
	# Fica nesse estado invulnerável até a animação acabar
	await _animated_sprite.animation_finished
	
	# Só então ele volta pro ciclo normal de combate
	if state != State.DEAD and state != State.JETPACK_TAKEOFF:
		start_cycle()

func _on_frame_changed():
	if state == State.THROW and _animated_sprite.animation == "throw":
		if _animated_sprite.frame == 8: 
			spawn_bouncing_bomb()

func spawn_bouncing_bomb():
	var bomb = BouncingBomb.instantiate()
	bomb.global_position = _throw_spawn.global_position
	if "facing" in bomb: bomb.facing = facing
	get_tree().current_scene.add_child(bomb)

func spawn_auto_parachute_bomb():
	if _player == null or state == State.DEAD: return
	var bomb = ParachuteBomb.instantiate()
	var spawn_y = global_position.y - 150
	bomb.global_position = Vector2(_player.global_position.x, spawn_y)
	get_tree().current_scene.add_child(bomb)

func set_direction(dir):
	facing = dir
	_animated_sprite.flip_h = (dir == 1) 
	_throw_spawn.position.x = abs(_throw_spawn.position.x) * (1 if dir == 1 else -1) 

func update_facing():
	if _player == null or state == State.DEAD: return
	if state == State.JETPACK_CHARGE or state == State.JETPACK_TAKEOFF: return
	var dir = 1 if _player.global_position.x > global_position.x else -1
	set_direction(dir)

func start_drop_bomb():
	if state == State.DEAD or state == State.JETPACK_TAKEOFF: return
	state = State.DROP_BOMB
	_animated_sprite.play("idle") 
	spawn_auto_parachute_bomb()
	await get_tree().create_timer(1.0).timeout
	if state == State.DROP_BOMB:
		start_cycle()

# -------------------------
# JETPACK
# -------------------------

func start_jetpack_init():
	if state == State.JETPACK_TAKEOFF or state == State.JETPACK_CHARGE: return
	state = State.JETPACK_TAKEOFF
	_animated_sprite.play("jetpack_takeoff")
	damage_accumulated = 0 
	
	await get_tree().create_timer(1.0).timeout
	if state == State.JETPACK_TAKEOFF:
		start_jetpack_charge()

func start_jetpack_charge():
	state = State.JETPACK_CHARGE
	_animated_sprite.play("jetpack_charge")
	bomb_spawn_timer = 0.0 
	
	if global_position.x < SCREEN_WIDTH_HALF:
		charge_direction = 1
	else:
		charge_direction = -1
		
	set_direction(charge_direction)
	_jetpack_col.set_deferred("disabled", false)
	_jetpack_hitbox.set_deferred("monitoring", true)

func _on_limit_body_entered(body):
	if body == self and state == State.JETPACK_CHARGE:
		start_landing()

func start_landing():
	if state == State.JETPACK_LANDING: return
	state = State.JETPACK_LANDING
	_jetpack_col.set_deferred("disabled", true)
	_jetpack_hitbox.set_deferred("monitoring", false)
	_animated_sprite.play("jetpack_landing")
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", start_y, 0.4)
	await _animated_sprite.animation_finished
	start_cycle()

# -------------------------
# DANOS E MORTE
# -------------------------

func take_damage(damage = 1):
	# 5. O Escudo! Se ele estiver morto ou Rindo (State.LAUGH), ignora o soco do Batman!
	if state == State.DEAD or state == State.LAUGH: return
	
	var tween = create_tween()
	_animated_sprite.modulate = Color(10, 10, 10)
	tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.15)
	
	health = max(health - damage, 0)
	damage_accumulated += damage 
	emit_signal("health_changed", health)
	
	if health <= 0:
		die()
		return

	if damage_accumulated >= DAMAGE_THRESHOLD_FOR_JETPACK and state != State.JETPACK_CHARGE and state != State.JETPACK_TAKEOFF:
		start_jetpack_init()

func die():
	state = State.DEAD
	_jetpack_col.set_deferred("disabled", true)
	_animated_sprite.play("death")
	await get_tree().create_timer(2.0).timeout
	emit_signal("died")
	queue_free()

func _on_jetpack_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"): body.take_damage(15)
		if body.has_method("heavy_stun"): body.heavy_stun()
