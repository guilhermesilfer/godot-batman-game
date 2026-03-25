extends CharacterBody2D
var pos:Vector2
var dir: float
var speed: int

func _ready() -> void:
	global_position = pos

func _physics_process(delta: float) -> void:
	velocity = Vector2(speed, 0)
	move_and_slide()
