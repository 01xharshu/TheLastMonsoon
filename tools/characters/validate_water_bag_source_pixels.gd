extends SceneTree
## Pouch-only native A/B: identical source geometry, no surrogate human body.
const BAG_PATH = 'res://player/water_bag_visual.gd'
const Pouch = preload('res://objects/household/water_pouch_visual.tscn')
var failures: Array[String] = []
var output := ''
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(('PASS ' if ok else 'FAIL ')+label)
	if not ok: failures.append(label)
func make_bag(parent: Node3D, cached: bool) -> Node3D:
	var bag: Node3D = load(BAG_PATH).new()
	bag.name = 'CachedPouch' if cached else 'ReferencePouch'
	bag.use_source_cpu_cache = cached
	bag.set_process(false)
	var model := Pouch.instantiate(); model.name = 'PouchModel'; bag.add_child(model)
	parent.add_child(bag)
	# Entering the tree enables scripted processing; freeze after _ready.
	bag.set_process(false)
	return bag
func pixels(viewport: SubViewport) -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--output='): output = arg.trim_prefix('--output=')
	if output.is_empty() or DisplayServer.get_name()=='headless': quit(2); return
	root.disable_3d = true
	var viewport := SubViewport.new(); viewport.size = Vector2i(640,640)
	viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage)
	# This invisible container owns a prop inventory; it is not a human stand-in.
	var host := Node3D.new(); stage.add_child(host)
	var inventory: Node = load('res://player/inventory_component.gd').new(); inventory.name='InventoryComponent'; host.add_child(inventory)
	var visual := Node3D.new(); host.add_child(visual)
	var equipment := Node3D.new(); visual.add_child(equipment)
	var reference := make_bag(equipment,false)
	var cached := make_bag(equipment,true)
	check(reference.source_readbacks==3 and cached.source_readbacks==0 and cached.source_cache_hits==1,'pouch setup eliminates all three GPU source readbacks')
	print('POUCH SETUP SOURCE COST ',JSON.stringify({'reference_us':reference.source_prepare_usec,'cached_us':cached.source_prepare_usec,'scope':'source input loop only, not whole-frame performance'}))
	var env := WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.16,.18,.20)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.8,.8,.8); env.environment.ambient_light_energy=.8
	stage.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-45,-35,0); stage.add_child(sun)
	var camera := Camera3D.new(); camera.fov=40; stage.add_child(camera)
	var target: Vector3=reference.pouch.to_global(Vector3(0,.17,0))
	camera.global_position=target+reference.pouch.global_basis.orthonormalized()*Vector3(.35,.08,.6)
	camera.look_at(target); camera.current=true
	for fill in [0.0,.5,1.0]:
		for bag in [reference,cached]: bag.fullness=fill; bag._rebuild()
		reference.show(); cached.hide()
		var before: Image = await pixels(viewport)
		var control: Image = await pixels(viewport)
		check(before.get_data()==control.get_data(),'frozen reference is stable at fill '+str(fill))
		reference.hide(); cached.show()
		var after: Image = await pixels(viewport)
		check(before.get_data()==after.get_data(),'cached source retains exact native pixels at fill '+str(fill))
		after.save_png(output+'/pouch_'+str(int(fill*100))+'.png')
	print('POUCH SOURCE NATIVE '+('PASS' if failures.is_empty() else 'FAIL'))
	preload('res://tools/test_audio_cleanup.gd').finish(self,0 if failures.is_empty() else 1)
