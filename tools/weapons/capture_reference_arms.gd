extends SceneTree
## Target-renderer contact sheet without the rejected Arjun export.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Weapon contact sheet requires a renderer")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.37,0.39,0.38)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8,0.82,0.84)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-28,0)
	sun.light_energy = 1.3
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 48
	camera.position = Vector3(0,2.4,7)
	camera.look_at(Vector3(0,0.83,0))
	camera.make_current()
	var items := [
		["Existing pistol","res://environment/weapons/adams_1851/adams_1851.glb",-3.2,0.85],
		["Existing talwar","res://environment/weapons/Talwar/weapon_talwar_01.glb",-2.0,0.82],
		["Bow","res://environment/weapons/period_bow/period_bow.glb",-0.75,0.12],
		["Quiver","res://environment/weapons/period_quiver/period_quiver.glb",0.52,0.20],
		["Arrow","res://environment/weapons/period_arrow/period_arrow.glb",1.65,0.22],
		["Spear","res://environment/weapons/period_spear/period_spear.glb",2.85,0.10],
	]
	var scenes: Array[Node3D] = []
	var labels: Array[Label3D] = []
	for item in items:
		var scene: Node3D = load(item[1]).instantiate()
		stage.add_child(scene)
		scene.position = Vector3(item[2],item[3],0)
		scenes.append(scene)
		var label := Label3D.new()
		label.text = item[0]
		label.font_size = 56
		label.pixel_size = 0.003
		label.position = Vector3(item[2],-0.22,0)
		label.modulate = Color(0.95,0.91,0.79)
		stage.add_child(label)
		labels.append(label)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/characters/arjun/weapon_set_review_2026-09-23.png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("WEAPON SET CAPTURE ",path)
	for label in labels: label.hide()
	for i in range(scenes.size()): scenes[i].hide()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	for i in range(2,6):
		var scene := scenes[i]
		scene.show()
		scene.position = Vector3.ZERO
		var center_y: float = [0.0,0.43,0.38,0.96][i-2]
		camera.size = [1.65,1.25,1.15,2.25][i-2]
		camera.position = Vector3(0,center_y+0.25,3.4)
		camera.look_at(Vector3(0,center_y,0))
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var detail_path: String = "res://docs/characters/arjun/weapon_%s_detail_2026-09-23.png" % String(items[i][0]).to_lower()
		assert(root.get_texture().get_image().save_png(detail_path) == OK)
		print("WEAPON DETAIL CAPTURE ",detail_path)
		scene.hide()
	quit()
