extends Area2D

@onready var _animated_sprite = $AnimatedSprite2D
var speed = 400

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _process(delta: float) -> void:
	_animated_sprite.play("default")

func _on_body_entered(body: Node2D) -> void:
	if body.is_invulnerable:
		return
	elif body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage()
	queue_free()

# frees the bullet once it gets outside the screen
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
