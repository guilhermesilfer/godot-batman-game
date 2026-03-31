extends CharacterBody2D

var speed = 100.0
var jump_velocity = -250.0
var bounces = 0
var max_bounces = 4
var facing = -1
var is_exploding = false

func _ready():
	$AnimatedSprite2D.play("default")
	velocity.x = speed * facing
	velocity.y = jump_velocity

func _physics_process(delta):
	if is_exploding: return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var collided = move_and_slide()
	
	if is_on_floor():
		bounces += 1
		if bounces >= max_bounces:
			collision_mask = 0 
			velocity.x = 0
			await get_tree().create_timer(1.5).timeout
			queue_free()
		else:
			velocity.y = jump_velocity

func _on_explosion_area_body_entered(body):
	if body.is_in_group("player") and not is_exploding and not body.is_invulnerable:
		explode()
		if body.has_method("take_damage"):
			body.take_damage(10)
		if body.has_method("stun"):
			body.stun()

func explode():
	is_exploding = true
	$AnimatedSprite2D.play("explosion")
	await $AnimatedSprite2D.animation_finished
	queue_free()
