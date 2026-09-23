extends SceneTree
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func run()->void:
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	for i in 5:await physics_frame
	var actor:CharacterBody3D=world.get_node("Player")
	actor.set_physics_process(false)
	var gate:Node3D=world.get_node("Settlement/ColonialCompound/BarredGate")
	actor.global_position=gate.global_position+Vector3(0,0,-2)
	gate.interact(actor)
	check(not gate.opened,"outside gate remains barred")
	actor.global_position=gate.global_position+Vector3(0,0,2)
	gate.interact(actor)
	check(gate.opened and gate.collision_layer==0,"gate opens from courtyard")
	var pickups:Array[Node]=get_nodes_in_group("weapon_pickups")
	check(pickups.size()>=2,"weapons placed in civic stores")
	var seen:Dictionary={}
	for pickup in pickups:
		var id:String=pickup.weapon_id
		if seen.has(id):continue
		seen[id]=true
		actor.global_position=pickup.global_position+Vector3(0,.4,.5)
		pickup.interact(actor)
		check(actor.inventory.has_item(id),"E takes "+id)
		var gear:Node=actor.get_node("VisualRoot/CharacterVisual").equipment
		print("GEAR ",id," held=",gear.held_name()," selected=",gear.selected," stowed=",gear.stowed," owns=",gear.owns(1 if id=="enfield" else 0))
		check(gear.held_name().to_lower().contains(id),"E equips "+id)
	check(seen.size()==2 and actor.get_meta("stolen_weapons",0)==2,"theft count records both weapons")
	print("COMPOUND INTERACTIONS ","PASS" if failures==0 else "FAIL "+str(failures))
	quit(1 if failures else 0)
