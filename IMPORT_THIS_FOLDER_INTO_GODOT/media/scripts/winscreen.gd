extends Node

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://media/scenes/menu.tscn")

func _on_menu_button_mouse_entered() -> void:
	$ButtonManager/MenuButton.modulate = Color(1.5, 1.5, 1.5)

func _on_menu_button_mouse_exited() -> void:
	$ButtonManager/MenuButton.modulate = Color(1, 1, 1)
