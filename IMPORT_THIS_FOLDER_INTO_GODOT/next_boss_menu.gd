extends Node2D

signal next_pressed

func _on_next_button_pressed() -> void:
	emit_signal("next_pressed")
	queue_free()
