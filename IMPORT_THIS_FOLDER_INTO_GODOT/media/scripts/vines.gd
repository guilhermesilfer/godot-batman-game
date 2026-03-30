extends Area2D

@onready var _anim_player = $AnimationPlayer
@onready var _collision = $CollisionShape2D # Certifique-se do nome do nó

var _is_dying = false

func _ready():
	# Começa pelo aviso visual
	_collision.disabled = true
	modulate.a = 0.3 # Fica transparente
	_anim_player.play("warn") 
	
	# Espera o tempo do "aviso" (ex: 0.5 segundos)
	await get_tree().create_timer(0.6).timeout
	
	# Agora ataca de verdade
	attack()

func attack():
	if _is_dying: return
	modulate.a = 1.0 # Fica sólida
	_collision.disabled = false
	_anim_player.play("grow")

func start_death():
	if _is_dying: return
	_is_dying = true
	_collision.set_deferred("disabled", true)
	_anim_player.play("shrink")
	await _anim_player.animation_finished
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("player") and not _is_dying:
		if body.has_method("heavy_stun"): body.heavy_stun()
		if body.has_method("take_damage"): body.take_damage(25)
		start_death()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "grow":
		await get_tree().create_timer(0.8).timeout
		start_death()
