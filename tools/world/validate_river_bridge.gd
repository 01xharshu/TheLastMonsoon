extends SceneTree
## Checks the widened river and complete deck/ramp, not just the middle crossing.
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func run()->void:
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	var bridge:Node3D=world.get_node("TimberBridge")
	for i in 5:await physics_frame
	var layout=world.layout
	var river_half:float=layout.river_width(165.0)
	check(bridge.HALF_SPAN>river_half+35,"bridge span misses banks")
	check(bridge.deck_height>=6.0,"boat and rider clearance too low")
	var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	for offset in range(-140,141,2):
		var x:float=bridge.global_position.x+offset
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,45,165),Vector3(x,-10,165)))
		check(not hit.is_empty(),"missing deck/ramp at %d"%offset)
		if not hit.is_empty(): check(hit.position.y>=layout.height(x,165)-.4,"bridge below bank at %d"%offset)
	var actor:CharacterBody3D=world.get_node("Player")
	actor.set_physics_process(false)
	for side in [-1.0,1.0]:
		var start_x:float=bridge.global_position.x+side*(bridge.HALF_SPAN+bridge.RAMP+2)
		actor.global_position=Vector3(start_x,layout.height(start_x,165)+1.0,165)
		var direction:float=-side
		for step in 3150:
			actor.velocity=Vector3(direction*7.0,actor.velocity.y-9.8/60.0,0)
			actor.move_and_slide()
			await physics_frame
		check(direction*(actor.global_position.x-bridge.global_position.x)>bridge.HALF_SPAN+bridge.RAMP+1,"cannot cross full bridge from side %s"%side)
	print("RIVER BRIDGE ","PASS" if failures==0 else "FAIL "+str(failures)," | half width ",river_half," m | deck ",bridge.deck_height," m")
	quit(1 if failures else 0)
