extends CharacterBody2D

var speed = 100.0
var jump_velocity = -250.0
var bounces = 0
var max_bounces = 4
var facing = -1 # Receberá o valor do Joker

func _ready():
	# Define a velocidade inicial baseada na direção do Joker
	velocity.x = speed * facing
	velocity.y = jump_velocity

func _physics_process(delta):
	# Aplica gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Move e verifica colisão
	var collided = move_and_slide()
	
	if is_on_floor():
		bounces += 1
		if bounces >= max_bounces:
			# Desativa colisão com o chão para cair "para dentro" do mapa
			collision_mask = 0 
			velocity.x = 0
			# Deleta após cair um pouco
			await get_tree().create_timer(1.5).timeout
			queue_free()
		else:
			# Quica
			velocity.y = jump_velocity

func _on_explosion_area_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(10)
		if body.has_method("stun"):
			body.stun()
		queue_free()
