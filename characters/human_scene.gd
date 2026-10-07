extends RefCounted
## Use Godot's imported MakeHuman assets; never decode GLBs again during play.
## Geometry/textures remain shared; mutable animation libraries belong to each actor.

static func instantiate(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Cannot load imported human scene: " + path)
		return null
	var figure := packed.instantiate() as Node3D
	for player in figure.find_children("*", "AnimationPlayer", true, false):
		for name in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(name).duplicate(true)
			player.remove_animation_library(name)
			player.add_animation_library(name, library)
	return figure
