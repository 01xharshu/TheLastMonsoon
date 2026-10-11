extends RefCounted
const Identity=preload("res://systems/entity_identity.gd")
const Permission=preload("res://systems/vehicle_permissions.gd")

static func collect(world: Node3D) -> Array:
	var states:Array=[]
	for horse in world.get_tree().get_nodes_in_group("horses"):
		if not world.is_ancestor_of(horse) or horse.is_in_group("police_mounts"):continue
		var at:Vector3=horse.global_position
		var state:=Permission.export_state(horse)
		state.merge({"entity_id":Identity.id_for(world,horse),"path":str(world.get_path_to(horse)),"position":[at.x,at.y,at.z],"heading":horse.rotation.y,"mounted":is_instance_valid(horse.rider) and horse.rider==world.get_node("Player"),"stolen":horse.stolen})
		states.append(state)
	return states

static func restore(world: Node3D, states: Array) -> void:
	var identities:=Identity.index_group(world,&"horses")
	var actor:CharacterBody3D=world.get_node("Player")
	for state in states:
		if not state is Dictionary:continue
		var horse:=Identity.resolve(world,state,identities)
		if horse==null or not horse.is_in_group("horses") or horse.is_in_group("police_mounts"):continue
		var at: Array=state.get("position",[])
		if at.size()!=3:continue
		var position:=Vector3(float(at[0]),float(at[1]),float(at[2]))
		var heading:=float(state.get("heading",0))
		if not position.is_finite() or not is_finite(heading):continue
		horse.global_position=position;horse.rotation.y=heading
		Permission.restore_state(horse,state,bool(state.get("mounted",false)))
		horse.stolen=bool(state.get("stolen",false))
		var mount: Node=actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null
		if state.get("mounted",false) and not is_instance_valid(mount):
			if actor.global_position.distance_squared_to(position)>9.0:continue
			horse.set_meta("restore_in_progress",true)
			horse.board(actor)
			horse.remove_meta("restore_in_progress")
