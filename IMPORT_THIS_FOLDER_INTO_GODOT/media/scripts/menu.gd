extends Node2D
@onready var _menu_song = $MenuSong

func _ready():
	_menu_song.play()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://media/scenes/arena.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
