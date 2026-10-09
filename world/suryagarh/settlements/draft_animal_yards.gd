extends Node3D
const Animal=preload("res://animals/draft_animal.gd")
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var pending_state:Dictionary={}
var restore_wait:=0.0
func _ready()->void:
	name="DraftAnimalYards";prepare.call_deferred()
func prepare()->void:
	await get_tree().process_frame
	var stable:=get_tree().root.find_child("CavalryStables",true,false) as Node3D
	if stable!=null:
		for index in 4:
			var animal:=Animal.new();animal.name="StableDraftHorse%02d"%index;animal.identity="stable_horse_%02d"%index
			add_child(animal);animal.global_position=stable.to_global(Vector3(-12+index*8,.24,-1.4));animal.build()
			await get_tree().process_frame
	var yard:=Node3D.new();yard.name="VillageBullockYard";yard.position=Vector3(-402,layout.height(-402,214),214);add_child(yard)
	var builder=preload("res://world/suryagarh/settlements/settlement_builder.gd").new()
	var earth:=StandardMaterial3D.new();earth.albedo_color=Color(.42,.29,.17);earth.roughness=1
	for side in [-1,1]:builder.piece(yard,"YardBoundary",Vector3(side*6,1,0),Vector3(.25,2,12),earth)
	builder.piece(yard,"YardRear",Vector3(0,1,-6),Vector3(12,2,.25),earth)
	for side in [-1,1]:builder.piece(yard,"YardEntrance",Vector3(side*4.1,1,6),Vector3(3.8,2,.25),earth)
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color(.25,.16,.09)
	builder.piece(yard,"FeedTrough",Vector3(0,.45,-4.6),Vector3(8,.25,.65),wood)
	for index in 4:
		var animal:=Animal.new();animal.kind="bullock";animal.name="VillageDraftBullock%02d"%index;animal.identity="village_bullock_%02d"%index
		add_child(animal);animal.global_position=yard.to_global(Vector3(-3+index*2,.02,-1));animal.build()
		await get_tree().process_frame
	builder.free()

func export_state()->Dictionary:
	var state:Dictionary={"teams":{},"animals":{}}
	var world:Node=get_parent()
	for cart in get_tree().get_nodes_in_group("cart_parking_vehicles"):
		if not world.is_ancestor_of(cart) or not cart.has_node("DraftTeam"):continue
		var rows:Array=[]
		for slot in cart.get_node("DraftTeam").slots:
			rows.append({"attached":slot.attached,"health":slot.health.health,"animal":slot.animal.identity if is_instance_valid(slot.animal) else ""})
		state.teams[str(world.get_path_to(cart))]=rows
	for animal in get_tree().get_nodes_in_group("draft_animals"):
		if not world.is_ancestor_of(animal):continue
		var p:Vector3=animal.global_position
		state.animals[animal.identity]={"position":[p.x,p.y,p.z],"heading":animal.global_rotation.y,"health":animal.vitality.health,"kind":animal.kind}
	return state

func restore_state(state:Dictionary)->void:
	pending_state=state.duplicate(true);restore_wait=0.0

func _process(delta:float)->void:
	if pending_state.is_empty():return
	restore_wait+=delta
	if restore_wait<.25:return
	restore_wait=0
	var world:Node=get_parent()
	var teams:Dictionary=pending_state.get("teams",{}) if pending_state.get("teams",{}) is Dictionary else {}
	var animals:Dictionary=pending_state.get("animals",{}) if pending_state.get("animals",{}) is Dictionary else {}
	for path in teams.keys():
		if str(path).begins_with("/") or ".." in str(path):teams.erase(path);continue
		var cart:=world.get_node_or_null(NodePath(path))
		if cart==null or not cart.has_node("DraftTeam"):continue
		var team:Node=cart.get_node("DraftTeam")
		if team.slots.is_empty():continue
		var rows:Variant=teams[path]
		if not rows is Array or rows.size()!=team.slots.size():teams.erase(path);continue
		var ready:=true
		for i in rows.size():
			if not rows[i] is Dictionary:continue
			var health:Variant=rows[i].get("health",90)
			if (health is int or health is float) and is_finite(float(health)) and float(health)>=0:
				team.slots[i].health.take_damage(maxf(0,team.slots[i].health.health-float(health)))
			var id:String=str(rows[i].get("animal",""))
			if not bool(rows[i].get("attached",true)):
				if team.slots[i].attached:team.detach(i)
			elif not id.is_empty():
				var found:Node3D
				for animal in get_tree().get_nodes_in_group("draft_animals"):
					if animal.identity==id:found=animal;break
				if found==null:ready=false;continue
				if team.slots[i].animal!=found:
					if team.slots[i].attached:team.detach(i)
					found.global_position=cart.to_global(Vector3(-2.5,0,-1.1));team.attach(found,i)
		if ready:teams.erase(path)
	for id in animals.keys():
		var found:Node3D
		for animal in get_tree().get_nodes_in_group("draft_animals"):
			if animal.identity==id:found=animal;break
		if found==null:continue
		var record:Variant=animals[id]
		if not record is Dictionary:animals.erase(id);continue
		var p:Variant=record.get("position",[])
		if found.team==null and p is Array and p.size()==3 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int) and (p[2] is float or p[2] is int):
			var point:=Vector3(float(p[0]),float(p[1]),float(p[2]))
			if point.is_finite() and absf(point.x)<2000 and absf(point.z)<2000:found.global_position=point
		var health:Variant=record.get("health",90)
		if (health is int or health is float) and is_finite(float(health)) and float(health)>=0:found.vitality.take_damage(maxf(0,found.vitality.health-float(health)))
		var heading:Variant=record.get("heading",0)
		if found.team==null and (heading is int or heading is float) and is_finite(float(heading)):found.global_rotation.y=float(heading)
		found.leader=null;animals.erase(id)
	if teams.is_empty() and animals.is_empty():pending_state.clear()
