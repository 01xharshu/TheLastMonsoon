extends SceneTree
## Full-cycle mechanics; rendered contact approval is a separate review.
var failures := 0
var report := {}
var captured := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func sample(boat: Node3D, visual: Node3D, label: String, frames: int) -> void:
	var worst := 0.0
	var wet := false
	var dry := false
	var powered := false
	var recovery_without_push := false
	var pushed_when_dry := false
	for i in frames:
		await physics_frame
		visual._process(1.0/60.0)
		boat._sync_rider()
		visual._process(1.0/60.0)
		for side in ["l","r"]:
			var rig: Skeleton3D = visual.skeleton
			var hand: Transform3D = rig.get_bone_global_pose(rig.find_bone("hand_"+side))
			var palm := rig.to_global(hand*visual.equipment.palm_offsets[side])
			worst = maxf(worst,palm.distance_to(boat.paddle_grip_world(side)))
		wet = wet or boat.paddle_blade_world().y<.07
		dry = dry or boat.paddle_blade_world().y>.12
		powered = powered or boat.stroke_power>.1
		recovery_without_push = recovery_without_push or (not boat.blade_in_water and boat.stroke_power==0.0)
		pushed_when_dry = pushed_when_dry or (not boat.blade_in_water and boat.stroke_power>0.0)
		if DisplayServer.get_name()!="headless" and label=="forward" and not captured and boat.paddle_contacts>=2 and boat.blade_in_water:
			captured=true
			var camera:=Camera3D.new()
			boat.get_parent().add_child(camera)
			var lateral: float=signf((boat.paddle_blade_world()-boat.global_position).dot(boat.global_basis.x))
			camera.global_position=boat.global_position+boat.global_basis.x*lateral*3.0+Vector3.UP*1.6+boat.global_basis.z*1.4
			camera.look_at(boat.seat_world()+Vector3.UP*.3)
			camera.make_current()
			boat.rider.get_node("UI").hide()
			boat.get_parent().get_node("LandscapeUI").hide()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://docs/world/captures/boat_paddle_water_contact.png")==OK,"capture paddle water contact")
	report[label] = {"max_palm_error_m":worst,"water_entry":wet,"recovery":dry}
	check(worst<.04,label+" full-cycle palm contact")
	check(wet and dry,label+" blade water entry and recovery")
	check(powered and recovery_without_push and not pushed_when_dry,label+" propulsion follows submerged power stroke")
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	for i in 5: await physics_frame
	var boat: Node3D=world.get_node("RiverBoat")
	var actor: CharacterBody3D=world.get_node("Player")
	var visual: Node3D=actor.get_node("VisualRoot/CharacterVisual")
	actor.set_physics_process(false)
	visual.set_process(false)
	actor.global_position=boat.global_position+Vector3(-2,1.2,0)
	var layer := actor.collision_layer
	var mask := actor.collision_mask
	check(boat.board(actor),"board boat")
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
		visual._process(1.0/60.0)
	await sample(boat,visual,"forward",120)
	check(boat.speed>0,"forward rowing accelerates boat")
	check(boat.paddle_contacts>0,"paddle water entry emits ripples")
	Input.action_release("move_forward")
	Input.action_press("move_backward")
	await physics_frame
	await physics_frame
	check(boat.row_drive>0.0,"reverse input eases instead of instantly flipping stroke")
	await sample(boat,visual,"reverse",180)
	check(boat.row_drive<-.99,"reverse input reaches full reverse stroke")
	check(boat.speed<0,"reverse rowing reverses boat")
	var heading: float=boat.rotation.y
	Input.action_press("move_left")
	await sample(boat,visual,"steering",90)
	check(absf(boat.rotation.y-heading)>.25,"steering changes heading while rowing")
	Input.action_release("move_left")
	Input.action_release("move_backward")
	for i in 30: await physics_frame
	var phase: float=boat.row_phase
	var contacts: int=boat.paddle_contacts
	for i in 15: await physics_frame
	check(boat.row_drive==0.0 and boat.row_effort==0.0 and is_equal_approx(phase,boat.row_phase),"idle stops stroke")
	check(boat.paddle_contacts==contacts,"idle emits no paddle ripples")
	var deck: MeshInstance3D=boat.hull.find_child("DryInnerDeck",true,false)
	check(deck!=null and deck.to_global(deck.get_aabb().position).y>.069,"inner deck stays above river wave maximum")
	check(boat.dismount(),"dismount after reversing and steering")
	check(actor.collision_layer==layer and actor.collision_mask==mask,"dismount restores actor collision")
	check(boat.paddle.transform.is_equal_approx(boat.paddle_stow),"dismount returns paddle to storage")
	check(boat.row_drive==0.0,"dismount clears rowing drive")
	report["failures"]=failures
	var file:=FileAccess.open("res://docs/world/boat_stroke_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BOAT STROKE ","PASS" if failures==0 else "FAIL")
	quit(1 if failures else 0)
