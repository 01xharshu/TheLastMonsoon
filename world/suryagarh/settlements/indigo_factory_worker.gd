extends "res://characters/npcs/indian/indian_street_actor.gd"
## Existing complete MPFB workman; own AnimationTree work branch and hand contact.
const Budget=preload("res://systems/simulation_budget.gd")
var factory:Node3D
var role:="beater"
var elapsed:=0.0
var accumulated:=0.0
var tool:Node3D
var work_active:=false
var target:Vector3
var path:Array[Vector3]=[]
var path_index:=0
var travelled:=0.0
var updates:=0
var blocked:=false
var world:Node3D
var viewer:Node3D
var sound_elapsed:=0.0

func _ready() -> void:
	household_job="Cook";movement_enabled=false
	super._ready()
	for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end=120.0;mesh.visibility_range_end_margin=12.0
	world=factory.get_parent();viewer=world.get_node_or_null("Player")
	tool=Node3D.new();tool.name="VatPaddle" if role=="beater" else "LeafCarrierTray"
	if role=="press":
		factory.get_node("FactoryArchitecture/PressHouse").add_child(tool);tool.position=Vector3(0,1.65,0)
	else:add_child(tool)
	if role=="beater":
		factory.piece(tool,"PaddleShaft",Vector3(0,-.25,0),Vector3(.035,1.1,.035),"wood",false)
		factory.piece(tool,"PaddleBlade",Vector3(0,-.85,0),Vector3(.23,.28,.04),"wood",false)
	elif role=="carrier":
		factory.piece(tool,"CarrierTray",Vector3(0,0,0),Vector3(.70,.07,.45),"wood",false)
		var leaves:=MultiMeshInstance3D.new();leaves.name="FreshLeaves"
		var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=factory.crop_mesh;batch.instance_count=8
		for i in 8:
			batch.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,PI*.5).scaled(Vector3.ONE*.4),Vector3((i%4-1.5)*.12,.08,(i/4-.5)*.14)))
		leaves.multimesh=batch;leaves.material_override=factory.materials.leaves;tool.add_child(leaves)
	else:
		tool.name="PressTurningBar"
		factory.piece(tool,"HandBar",Vector3(0,0,0),Vector3(2.2,.06,.06),"wood",false)
	set_meta("external_combat_motion",true)
	set_meta("population_expansion_exempt",true)
	set_meta("factory_role",role)

func _process(delta:float) -> void:
	if get_meta("dead",false) or get_meta("knocked_out",false) or get_meta("paired_combat",false):
		if tool!=null and role!="press":tool.hide()
		return
	accumulated+=delta
	if accumulated<Budget.interval(self,viewer,get_meta("combat_action","")!=""):return
	delta=accumulated;accumulated=0;elapsed+=delta;updates+=1
	if not factory.configured:return
	var operations:Node=factory.operations
	work_active=operations.is_open() and (role!="carrier" or operations.raw_bundles>0)
	var walking:=false
	if role=="carrier" and work_active and path.size()>1:
		var destination:Vector3=path[path_index]
		var offset:=destination-global_position
		if Vector2(offset.x,offset.z).length()<.10:path_index=(path_index+1)%path.size()
		else:
			var step:=offset.limit_length(delta*.8)
			var next:=global_position+step
			next.y=factory.height_at(Vector2(next.x,next.z))+.04
			step=next-global_position
			var shape:CollisionShape3D=body_collider.get_node("BodyShape")
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform
			query.exclude=[body_collider.get_rid()];query.collision_mask=1;query.margin=.01;query.motion=step
			blocked=get_world_3d().direct_space_state.cast_motion(query)[0]<.99
			if not blocked:
				global_position+=step;travelled+=step.length();travel_speed=.8;walking=true
				rotation.y=rotate_toward(rotation.y,atan2(offset.x,offset.z),delta*2.5)
			else:travel_speed=0
	else:travel_speed=0
	_set_animation(&"walk" if walking else &"idle",delta)
	tool.visible=role=="press" or (work_active and (role=="carrier" or (role=="beater" and operations.phase=="beating")))
	var working:bool=work_active and tool.visible and (role!="press" or operations.phase=="pressing")
	sound_elapsed+=delta
	if working and role in ["beater","press"] and sound_elapsed>1.8 and is_instance_valid(viewer) and viewer.global_position.distance_squared_to(global_position)<24*24:
		sound_elapsed=0
		WorldAudio.play_at("splash" if role=="beater" else "wheel_creak",tool.global_position,-25.0)
	elif walking and role=="carrier" and sound_elapsed>.65 and is_instance_valid(viewer) and viewer.global_position.distance_squared_to(global_position)<24*24:
		sound_elapsed=0;WorldAudio.play_at("step_dirt",global_position,-26.0)
	if animation_tree!=null:animation_tree.set("parameters/work_pose/blend_amount",1.0 if working else 0.0)
	if not tool.visible:return
	if role=="beater":
		tool.global_position=global_position+global_basis*Vector3(0,1.12,.42)
		tool.rotation=Vector3(.24+sin(elapsed*2.3)*.16,0,.04)
		solve_hand_contact("l",tool.to_global(Vector3(0,.20,0)))
		solve_hand_contact("r",tool.to_global(Vector3(0,-.10,0)))
	elif role=="carrier":
		tool.position=Vector3(0,.96,.34)
		solve_hand_contact("l",tool.to_global(Vector3(.30,.04,0)))
		solve_hand_contact("r",tool.to_global(Vector3(-.30,.04,0)))
	else:
		var machine:Node3D=factory.get_node("FactoryArchitecture/PressHouse")
		tool.global_position=machine.to_global(Vector3(0,1.65,0))
		tool.global_rotation=Vector3(0,sin(elapsed*.7)*.12 if operations.phase=="pressing" and work_active else 0,0)
		if operations.phase=="pressing" and work_active:
			solve_hand_contact("l",tool.to_global(Vector3(.93,.035,0)))
			solve_hand_contact("r",tool.to_global(Vector3(1.08,.035,0)))
	set_grip("l",.55);set_grip("r",.55)

func export_state() -> Dictionary:
	var vitality:=get_node_or_null("Vitality")
	return {"id":get_meta("entity_id"),"health":vitality.health if vitality!=null else 75.0,"dead":get_meta("dead",false),"knocked_out":get_meta("knocked_out",false),"path_index":path_index,"position":[global_position.x,global_position.y,global_position.z],"elapsed":elapsed}

func restore_state(data:Dictionary) -> void:
	var vitality:=get_node_or_null("Vitality")
	if vitality!=null:
		vitality.health=clampf(float(data.get("health",75)),0,75)
		vitality.dead=bool(data.get("dead",false))
	set_meta("dead",bool(data.get("dead",false)));set_meta("knocked_out",bool(data.get("knocked_out",false)))
	path_index=clampi(int(data.get("path_index",0)),0,maxi(0,path.size()-1));elapsed=maxf(0,float(data.get("elapsed",0)))
	var saved:Variant=data.get("position",[])
	if saved is Array and saved.size()==3:
		var p:=Vector3(float(saved[0]),float(saved[1]),float(saved[2]))
		if p.is_finite() and Vector2(p.x,p.z).distance_to(factory.Data.CENTER)<45:global_position=p
	var inactive:bool=get_meta("dead",false) or get_meta("knocked_out",false)
	if body_collider!=null:
		body_collider.get_node("BodyShape").set_deferred("disabled",inactive)
		body_collider.force_update_transform()
	var motion:=get_node_or_null("CombatMotion")
	if motion!=null:
		if inactive:motion.play("down")
		else:
			motion.state="";motion.set_process(false);set_meta("combat_action","")
			animation_tree.active=true;animation_tree.set("parameters/combat/blend_amount",0.0)
	if inactive and tool!=null and role!="press":tool.hide()
