extends Node
## Slots preserve original rigged animals and their health when a team is uncoupled.
const Animal=preload("res://animals/draft_animal.gd")
var cart:Node3D
var slots:Array[Dictionary]=[]
var kind := "horse"

func _ready()->void:
	cart=get_parent();kind="bullock" if cart.get_meta("bullock_cart",false) else "horse"
	prepare.call_deferred()

func prepare()->void:
	for health in cart.combat.horses:
		slots.append({"health":health,"model":health.model,"pose":health.model.transform,"animal":null,"attached":true})
	var handle=preload("res://vehicles/draft_team_handle.gd").new();handle.team=self;handle.name="TeamCoupling";handle.position=Vector3(-1.5,1,-1)
	var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.18;shape.shape=sphere;handle.add_child(shape);cart.add_child(handle);handle.add_to_group("cart_boarding_handles")

func can_move()->bool:
	if slots.is_empty():return cart.combat.can_move()
	for slot in slots:
		if not slot.attached or slot.health.dead:return false
	return true

func use(actor:CharacterBody3D)->void:
	if absf(cart.boarding.speed)>.1 or not cart.boarding.transition.is_empty():return
	for animal in get_tree().get_nodes_in_group("draft_animals"):
		if animal.leader==actor and animal.kind==kind and animal.can_lead() and animal.global_position.distance_to(cart.global_position)<6:
			for i in slots.size():
				if not slots[i].attached and attach(animal,i):return
	# Never tear down an occupied passenger transition or moving traffic.
	if cart.has_meta("errand_transfer"):return
	for i in slots.size():
		if slots[i].attached:detach(i)

func detach(index:int)->Node3D:
	if index<0 or index>=slots.size() or not slots[index].attached:return null
	var slot:Dictionary=slots[index]
	var animal:Node3D=slot.animal
	if animal==null:
		animal=Animal.new();animal.kind=kind;animal.name="Released_%s_%d"%[cart.name,index];animal.identity=str(cart.get_path())+":"+str(index)
		cart.get_parent().add_child(animal);animal.global_transform=Transform3D(cart.global_basis,slot.model.global_position)
		animal.adopt(slot.model,slot.health);slot.animal=animal
	else:animal.reparent(cart.get_parent(),true)
	animal.team=null;animal.get_node("LeadHandle").collision_layer=1;animal.collision_layer=1;animal.set_physics_process(true);slot.attached=false
	cart.boarding.speed=0;_harness();return animal

func detach_animal(animal:Node3D)->void:
	for i in slots.size():
		if slots[i].animal==animal:detach(i);return

func attach(animal:Node3D,index:int)->bool:
	if index<0 or index>=slots.size() or slots[index].attached or not animal.can_lead() or animal.kind!=kind:return false
	if animal.global_position.distance_to(cart.global_position)>6 or absf(cart.boarding.speed)>.1:return false
	var slot:Dictionary=slots[index]
	# Target animal volume must be clear before snapping the coupling into place.
	var target:Vector3=cart.visual_root.to_global(slot.pose.origin)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=animal.get_child(0).shape if animal.get_child(0) is CollisionShape3D else BoxShape3D.new()
	query.transform=Transform3D(cart.global_basis,target+Vector3.UP*.85);query.collision_mask=1;query.exclude=[animal.get_rid(),animal.get_node("LeadHandle").get_rid(),cart.boarding.collision_body.get_rid()]
	var hits:=cart.get_world_3d().direct_space_state.intersect_shape(query,1)
	if not hits.is_empty():
		print("DRAFT_HITCH_BLOCKED ",hits[0].collider.get_path());return false
	animal.reparent(cart.visual_root,true);animal.transform=Transform3D(Basis.IDENTITY,slot.pose.origin);animal.team=self;animal.get_node("LeadHandle").collision_layer=0;animal.leader=null;animal.collision_layer=0;animal.set_physics_process(false)
	slot.animal=animal;slot.health=animal.vitality;slot.model=animal.model;slot.attached=true
	cart.combat.horses[index]=animal.vitality
	if animal.animation!=null:cart.combat.horse_animations[animal.animation]=animal.vitality
	if cart.has_method("rebind_draft_slot"):cart.rebind_draft_slot(index,animal.model,animal.vitality)
	elif cart.get("horse_animations")!=null:cart.horse_animations[index]=animal.animation
	else:cart.horse_animation=animal.animation
	_harness();return true

func _harness()->void:
	var complete:=can_move()
	for mesh in cart.visual_root.find_children("*","MeshInstance3D",true,false):
		var label:String=str(mesh.get_meta("cart_part",mesh.get_meta("part_label",mesh.name)))
		if label in ["BreastStrap","OutsideTrace","InsideTrace","PoleStrap","BreastCollar","CollarToTrace","Rein","DraughtYoke","YokeBow"]:mesh.visible=complete
	var reins:=cart.get_node_or_null("FlexibleReins")
	if reins!=null:reins.set_process(complete);reins.set_physics_process(complete);reins.visible=complete
	for i in cart.boarding.clearance_shapes.size():
		if i>0 and (i<3 if cart.has_method("show_coachman_blockout") else i==1):cart.boarding.clearance_shapes[i].set_deferred("disabled",not complete)

func _physics_process(_delta:float)->void:
	if absf(cart.rotation.z)>.65 or absf(cart.rotation.x)>.65:
		for i in slots.size():
			if slots[i].attached:detach(i)

func animal_attached(health:Node)->bool:
	for slot in slots:
		if slot.health==health:return slot.attached
	return false
