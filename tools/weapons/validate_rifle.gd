extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_physics_process(false)
	var actor = world.get_node("Player")
	var visual = actor.get_node("VisualRoot/CharacterVisual")
	var rifle = actor.get_node("RifleCombat")
	rifle.set_process(false)
	actor.position = Vector3(-230,50,180)
	actor.rotation = Vector3.ZERO
	actor.is_swimming = false
	var camera: Camera3D = rifle.camera
	camera.get_parent().rotation = Vector3.ZERO
	actor.get_node("CameraPivot").rotation = Vector3.ZERO
	var target := StaticBody3D.new()
	world.add_child(target)
	target.position = actor.position+Vector3(0,1,-10)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8,8,.3)
	collision.shape = shape
	target.add_child(collision)
	var target_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	target_mesh.mesh = box
	target.add_child(target_mesh)
	for i in 5: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visual.equipment.selected = 1
	visual.equipment.stowed = false
	visual.equipment._refresh()
	visual.equipment.aiming = true
	visual.equipment.aim_direction = -camera.global_basis.z
	for i in 30: visual._process(1.0/60)
	rifle.aiming = true
	
	rifle.fire()
	check(rifle.shots_fired==1 and not rifle.loaded,"First shot must consume the chamber")
	check(rifle.impacts.size()==1,"Shot must leave one surface mark")
	check(rifle.sound.stream==rifle.SHOT,"Gunshot audio must be triggered")
	rifle.fire()
	check(rifle.shots_fired==1,"Empty rifle fired twice")
	actor.inventory.add_item("paper_cartridges",2)
	rifle.start_reload()
	check(rifle.reload_remaining>0,"Reload did not start")
	rifle._process(5.1)
	check(rifle.loaded,"Reload did not chamber a round")
	actor.set_meta("map_open",true)
	rifle.aiming = true
	rifle.fire()
	check(rifle.shots_fired==1,"Map allowed firing")
	actor.set_meta("map_open",false)
	# Obstacle immediately in front of muzzle must catch the shot before the target.
	var muzzle: Vector3 = visual.equipment.enfield_hand.to_global(rifle.MUZZLE)
	var cover := StaticBody3D.new()
	world.add_child(cover)
	cover.position = muzzle+Vector3(0,0,-.4)
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(3,3,.15)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	for i in 3: await physics_frame
	rifle.aiming = true
	rifle.fire()
	check(rifle.impacts.size()==2,"Cover shot missing mark")
	if rifle.impacts.size()==2: check(rifle.impacts[1].get_parent()==cover,"Shot passed through muzzle cover")
	print("RIFLE TEST ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
