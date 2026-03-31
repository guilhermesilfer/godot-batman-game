extends Area2D

var fall_speed = 150.0
var is_exploding = false

func _ready():
	$AnimatedSprite2D.play("falling")
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if is_exploding: return
	
	position.y += fall_speed * delta

func _on_body_entered(body):
	if body.is_in_group("player") and not is_exploding and not body.is_invulnerable:
		explode()
		if body.has_method("take_damage"):
			body.take_damage(15)
		if body.has_method("stun"):
			body.stun()

func explode():
	is_exploding = true
	$AnimatedSprite2D.play("explosion")
	await $AnimatedSprite2D.animation_finished
	queue_free()

func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()
