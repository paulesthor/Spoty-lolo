extends Node
# Entry point: the intro the first time, the title screen afterwards.
func _ready():
	var first: bool = not Meta.data.get("intro_seen", false)
	get_tree().change_scene_to_file.call_deferred("res://scenes/intro.tscn" if first else "res://scenes/title.tscn")
