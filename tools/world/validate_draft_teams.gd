extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label)
func run()->void:
	var world:=Node3D.new();world.name="TeamFixture";root.add_child(world);current_scene=world
	var floor:=StaticBody3D.new();world.add_child(floor);var support:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.1,100);support.shape=box;support.position.y=-.05;floor.add_child(support)
	for type in ["horse_cart_candidate","bullock_cart","family_carriage_candidate"]:
		var cart:Node3D=load("res://vehicles/"+type+".gd").new();cart.position.x=float(["horse_cart_candidate","bullock_cart","family_carriage_candidate"].find(type))*12;world.add_child(cart)
		for frame in 5:await physics_frame
		var team:Node=cart.get_node("DraftTeam")
		check(team.slots.size()==(1 if type=="horse_cart_candidate" else 2),type+": correct slots")
		check(cart.can_move(),type+": original team moves")
		var original:Node3D=team.slots[0].model;var original_health:Node=team.slots[0].health
		original_health.take_damage(10)
		var health:float=original_health.health
		var animal:Node3D=team.detach(0)
		check(animal!=null and animal.model==original,type+": original animal retained")
		check(animal.vitality==original_health and is_equal_approx(animal.vitality.health,health),type+": health retained")
		check(not cart.can_move(),type+": incomplete team stops cart")
		for frame in 2:await physics_frame
		if team.slots.size()>1:
			var probe:=CharacterBody3D.new();world.add_child(probe)
			animal.set_physics_process(false);animal.leader=probe
			var obstruction:=StaticBody3D.new();world.add_child(obstruction)
			var volume:=CollisionShape3D.new();var block:=BoxShape3D.new();block.size=Vector3(1.2,1.5,2.5)
			volume.shape=block;obstruction.add_child(volume)
			obstruction.global_position=cart.visual_root.to_global(team.slots[0].pose.origin)+Vector3.UP*.85
			for frame in 2:await physics_frame
			team.use(probe)
			check(team.slots[1].attached,type+": blocked hitch preserves other attached animal")
			animal.leader=null;animal.set_physics_process(true);obstruction.queue_free();probe.queue_free()
			for frame in 2:await physics_frame
		var attached:bool=team.attach(animal,0)
		check(attached,type+": original animal reattaches")
		if not attached:print("TEAM_ATTACH_FAILED ",type," animal ",animal.global_position);continue
		check(cart.can_move(),type+": restored team moves")
		check(original==team.slots[0].model,type+": no duplicate animal created")
		animal=team.detach(0);animal.vitality.take_damage(1000)
		for frame in 100:await physics_frame
		check(not team.attach(animal,0),type+": dead animal cannot hitch")
		animal.global_position+=Vector3(4,0,0)
		for frame in 2:await physics_frame
		var replacement:=preload("res://animals/draft_animal.gd").new();replacement.kind=team.kind;world.add_child(replacement);replacement.global_position=cart.to_global(Vector3(-2.5,0,-1.1));replacement.build()
		check(team.attach(replacement,0),type+": yard animal replaces fallen animal")
		check(cart.can_move(),type+": replacement restores traction")
		check(animal.is_inside_tree() and animal.vitality.dead,type+": fallen original remains in world")
		# Save restoration must read the numeric vitality.health once, not .health.health.
		replacement.identity="fixture_"+type
		var yard=load("res://world/suryagarh/settlements/draft_animal_yards.gd").new();world.add_child(yard)
		var state:Dictionary=yard.export_state()
		var restored_health:float=maxf(0,replacement.vitality.health-7)
		state.animals[replacement.identity].health=restored_health
		yard.restore_state(state);yard._process(.3)
		check(is_equal_approx(replacement.vitality.health,restored_health),type+": saved numeric animal health restores")
		check(yard.pending_state.is_empty(),type+": animal/team restore completes")
		yard.restore_state({"animals":{"missing_identity":{"health":70}}});yard._process(31)
		check(yard.pending_state.is_empty(),type+": stale identity stops retrying")
		# Free before its deferred yard/animal builder runs in this small fixture.
		yard.free()
		cart.queue_free();animal.queue_free()
		for frame in 2:await physics_frame
	print("DRAFT_TEAM_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
