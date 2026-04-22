extends Node2D

@onready var _menu_song = $MenuSong

func _ready():
	_menu_song.play()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://media/scenes/arena.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_start_button_mouse_entered() -> void:
	$ButtonManager/StartButton.modulate = Color(1.5, 1.5, 1.5)

func _on_start_button_mouse_exited() -> void:
	$ButtonManager/StartButton.modulate = Color(1, 1, 1)

func _on_quit_button_mouse_entered() -> void:
	$ButtonManager/QuitButton.modulate = Color(1.5, 1.5, 1.5)

func _on_quit_button_mouse_exited() -> void:
	$ButtonManager/QuitButton.modulate = Color(1, 1, 1)
