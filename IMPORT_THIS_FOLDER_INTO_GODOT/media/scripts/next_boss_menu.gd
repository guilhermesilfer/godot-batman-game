extends Node2D

signal next_pressed

func _on_next_button_pressed() -> void:
	emit_signal("next_pressed")
	queue_free()

func _on_next_button_mouse_entered() -> void:
	$ButtonManager/NextButton.modulate = Color(1.5, 1.5, 1.5)

func _on_next_button_mouse_exited() -> void:
	$ButtonManager/NextButton.modulate = Color(1, 1, 1)
