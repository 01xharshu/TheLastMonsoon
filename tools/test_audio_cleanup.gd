extends RefCounted
## Let the audio backend retire fixture playback before an immediate test exit.
static func stop(root: Node) -> void:
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player in root.find_children("*",kind,true,false):player.stop()
static func settle(tree: SceneTree) -> void:
	var deadline:=Time.get_ticks_msec()+100
	while Time.get_ticks_msec()<deadline:await tree.process_frame
