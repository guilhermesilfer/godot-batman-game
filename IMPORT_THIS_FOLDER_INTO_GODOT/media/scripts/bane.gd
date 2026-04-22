extends CharacterBody2D

enum State { HALT, LOAD, RUN, JUMP, REST, SPIN, DEAD }

const RUN_SPEED = 200.0
const JUMP_SPEED = 250.0
const MAX_HEALTH = 100
const LEFT_WALL = 45.0
const RIGHT_WALL = 275.0
const JUMP_VELOCITY = -400.0 

var health = MAX_HEALTH
var state = State.HALT
var facing = -1
var run_count = 0
var target_runs = 0
var jump_count = 0
var target_jumps = 0

var _is_dying := false 

@onready var _animated_sprite = $AnimatedSprite2D
@onready var _spin_area = $SpinArea
@onready var _charge_area = $ChargeArea
@onready var _jump_area = $JumpArea 

@onready var _spin_col = $SpinArea/CollisionShape2D
@onready var _charge_col = $ChargeArea/CollisionShape2D
@onready var _jump_col = $JumpArea/CollisionShape2D 

@onready var _grunt_sound1 = $BaneGrunt1
@onready var _grunt_sound2 = $BaneGrunt2

signal health_changed(new_health)
signal died

func _ready():
	health = MAX_HEALTH
	add_to_group("enemies")
	
	if _animated_sprite.sprite_frames.has_animation("jump"):
		_animated_sprite.sprite_frames.set_animation_loop("jump", false)
		
	if not _charge_area.body_entered.is_connected(_on_damage_area_body_entered):
		_charge_area.body_entered.connect(_on_damage_area_body_entered)
	if not _spin_area.body_entered.is_connected(_on_damage_area_body_entered):
		_spin_area.body_entered.connect(_on_damage_area_body_entered)
	if not _jump_area.body_entered.is_connected(_on_jump_damage_area_body_entered):
		_jump_area.body_entered.connect(_on_jump_damage_area_body_entered)
	
	if _spin_area: _spin_area.monitoring = true
	if _charge_area: _charge_area.monitoring = true
	if _jump_area: _jump_area.monitoring = true
	
	disable_all_hitboxes()
	set_direction(facing) 
	start_cycle()

func disable_all_hitboxes():
	if _spin_col: _spin_col.set_deferred("disabled", true)
	if _charge_col: _charge_col.set_deferred("disabled", true)
	if _jump_col: _jump_col.set_deferred("disabled", true)

func _physics_process(delta):
	if state == State.DEAD or _is_dying: 
		velocity.x = 0 
		move_and_slide()
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.RUN:
			velocity.x = facing * RUN_SPEED
			check_walls()
		State.JUMP:
			velocity.x = facing * JUMP_SPEED
			check_walls()
			
			if velocity.y < 0:
				_animated_sprite.play("jump")
				_animated_sprite.frame = 0
			elif velocity.y > 0 and not is_on_floor():
				_animated_sprite.play("jump")
				_animated_sprite.frame = 1
				
		State.HALT, State.LOAD, State.REST, State.SPIN:
			velocity.x = move_toward(velocity.x, 0, RUN_SPEED)

	move_and_slide()
	
	if state == State.JUMP and is_on_floor():
		landing()

func check_walls():
	if global_position.x <= LEFT_WALL and facing == -1:
		bounce()
	elif global_position.x >= RIGHT_WALL and facing == 1:
		bounce()

func bounce():
	if state == State.DEAD or _is_dying: return
	
	if state == State.RUN:
		run_count += 1
		set_direction(facing * -1)
		if run_count >= target_runs:
			start_jump() 
	elif state == State.JUMP:
		landing()

func landing():
	state = State.HALT 
	velocity.x = 0
	disable_all_hitboxes()
	
	_animated_sprite.play("jump")
	_animated_sprite.frame = 2
	
	await get_tree().create_timer(0.3).timeout 
	
	if state == State.DEAD or _is_dying: return
	
	jump_count += 1
	set_direction(facing * -1)
	
	if jump_count >= target_jumps:
		start_rest()
	else:
		start_jump()

func execute_load():
	if state == State.DEAD or _is_dying: return 
	
	state = State.LOAD
	disable_all_hitboxes()
	velocity.x = move_toward(velocity.x, 0, RUN_SPEED) 
	play_anim("load")
	
	# Efeito Visual: Ficar vermelho parado antes da investida
	var tween = create_tween()
	tween.tween_property(_animated_sprite, "modulate", Color.RED, 0.7)
	
	if randi() % 2 == 0:
		_grunt_sound1.play()
	else:
		_grunt_sound2.play()
		
	await get_tree().create_timer(1.5).timeout
	
	# Resetar cor antes de começar a correr
	_animated_sprite.modulate = Color.WHITE
	
	if state == State.DEAD or _is_dying: return

func start_cycle():
	if state == State.DEAD or _is_dying: return
	
	state = State.HALT
	disable_all_hitboxes()
	play_anim("halt")
	await get_tree().create_timer(1.0).timeout
	
	if state == State.DEAD or _is_dying: return
	start_run()

func start_run():
	if state == State.DEAD or _is_dying: return
	
	await execute_load()
	if state == State.DEAD or _is_dying: return
	
	state = State.RUN
	run_count = 0
	target_runs = randi_range(2, 4)
	
	if _charge_col: _charge_col.set_deferred("disabled", false)
	play_anim("run")

func start_jump():
	if state == State.DEAD or _is_dying: return
	
	await execute_load()
	if state == State.DEAD or _is_dying: return
	
	state = State.JUMP
	jump_count = 0
	target_jumps = randi_range(1, 2)
	
	velocity.y = JUMP_VELOCITY
	
	if _jump_col: _jump_col.set_deferred("disabled", false) 
	_animated_sprite.play("jump")

func start_rest():
	if state == State.DEAD or _is_dying: return
	
	state = State.REST
	disable_all_hitboxes()
	play_anim("halt")
	await get_tree().create_timer(4.0).timeout 
	
	if state == State.DEAD or _is_dying: return
	start_spin()

func start_spin():
	if state == State.DEAD or _is_dying: return
	
	await execute_load()
	if state == State.DEAD or _is_dying: return
	
	state = State.SPIN
	
	if _spin_col: _spin_col.set_deferred("disabled", false) 
	
	play_anim("spin")
	await get_tree().create_timer(1.5).timeout
	
	if state == State.DEAD or _is_dying: return
	start_cycle()

func set_direction(dir):
	if state == State.DEAD or _is_dying: return
	
	facing = dir
	_animated_sprite.flip_h = (facing == -1)
	
	if _spin_col: _spin_col.position.x = abs(_spin_col.position.x) * dir
	if _charge_col: _charge_col.position.x = abs(_charge_col.position.x) * dir
	
	if _jump_col: 
		_jump_col.position.x = abs(_jump_col.position.x) * dir 
		_jump_col.rotation_degrees = abs(_jump_col.rotation_degrees) * -dir

func play_anim(anim_name: String):
	# PROTEÇÃO VISUAL MÁXIMA: Impede novas animações se estiver morto
	if _is_dying and anim_name != "death": return
	
	if _animated_sprite.animation != anim_name:
		_animated_sprite.play(anim_name)

func take_damage(damage = 1):
	if state == State.DEAD or _is_dying: return
	
	var tween = create_tween()
	_animated_sprite.modulate = Color(10, 10, 10)
	tween.tween_property(_animated_sprite, "modulate", Color.WHITE, 0.15)
	
	health -= damage
	health = max(health, 0)
	emit_signal("health_changed", health)
	if health <= 0: die()

func die():
	if _is_dying: return
	_is_dying = true 
	
	state = State.DEAD
	velocity = Vector2.ZERO 
	
	set_physics_process(false)
	disable_all_hitboxes()
	
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
			
	# Para a animação atual imediatamente antes de tocar a morte
	_animated_sprite.stop()
	play_anim("death")
	
	await get_tree().create_timer(2.0).timeout
	
	emit_signal("died")
	queue_free()

func _on_damage_area_body_entered(body: Node2D) -> void:
	if state == State.DEAD or _is_dying: return
	if body.is_in_group("player"):
		_apply_damage_to_batman(body, 10)

func _on_jump_damage_area_body_entered(body: Node2D) -> void:
	if state == State.DEAD or _is_dying: return
	if body.is_in_group("player"):
		if body.get("is_crouching") == true:
			return 
		_apply_damage_to_batman(body, 15) 

func _apply_damage_to_batman(player_body, damage_amount):
	if player_body.has_method("take_damage") and not player_body.is_invulnerable:
		player_body.take_damage(damage_amount) 
	if player_body.has_method("heavy_stun") and not player_body.is_invulnerable:
		player_body.heavy_stun()
