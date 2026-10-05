extends "res://tools/world/capture_street_walk.gd"
func _ready()->void:
	super._ready()
	set_process(false);set_physics_process(false)
	for journey in journeys:journey.set_physics_process(false)
	_capture.call_deferred()
func _capture()->void:
	get_tree().root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute("/tmp/tlm_street_contact_frames")
	for frame in 750:
		for journey in journeys:journey.tick(1.0/30)
		var centre:Vector3=(journeys[0].actor.global_position+journeys[1].actor.global_position)*.5
		var camera:=get_viewport().get_camera_3d()
		camera.global_position=centre+Vector3(4,1.75,4);camera.look_at(centre+Vector3.UP*.85)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_jpg("/tmp/tlm_street_contact_frames/%04d.jpg"%frame,.94)
	print("STREET MOTION: 750 individually rendered steps at 1/30 s; cloth/contact art open")
	get_tree().quit()
