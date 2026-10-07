extends "res://tools/world/validate_combat_encounters.gd"
## Actual Suryagarh rendering; fixture placement is separate from player-route approval.
var review_camera: Camera3D
func check(ok: bool,label: String) -> void:
	super.check(ok,label)
	if review_camera==null:
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,720);root.content_scale_size=root.size
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		review_camera=Camera3D.new();review_camera.fov=42;world.add_child(review_camera)
		review_camera.make_current();player.get_node("UI").hide()
		world.get_node("GameTimeSystem").advance_hours(6)
func review(label: String) -> void:
	var label_path:=""
	var centre:=Vector3.ZERO
	match label:
		"approach triggers actual beating sequence":
			label_path="beating";centre=encounters.peasant.global_position+Vector3.UP
		"repeated British strikes cause living civilian fall":
			label_path="fallen_peasant";centre=encounters.peasant.global_position+Vector3.UP*.7
		"intervention stops abuse":
			label_path="rescue";centre=encounters.peasant.global_position+Vector3.UP
		"visible wanted player alerts only this officer":
			label_path="patrol_alert";centre=encounters.patrols[0].actor.global_position+Vector3.UP
		"second rear capture starts continuous escort":
			label_path="capture";centre=player.global_position+Vector3.UP*.2
	if label_path=="":return
	review_camera.global_position=centre+Vector3(-4.2,1.7,4.6)
	review_camera.look_at(centre)
	review_camera.make_current()
	review_camera.reset_physics_interpolation()
	review_camera.force_update_transform()
	for frame in 2:await process_frame
	RenderingServer.force_draw(false,1.0/60.0)
	root.get_texture().get_image().save_png("res://docs/characters/arjun/combat_world_%s_2026-10-06.png"%label_path)
	print("COMBAT WORLD CAPTURE ",label_path)
