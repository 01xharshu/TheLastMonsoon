extends CharacterBody3D
## A retained rigged animal can be led, hitched or left standing; no visual clone on hitching.
var kind := "horse"
var model:Node3D
var vitality:Node
var leader:CharacterBody3D
var team:Node
var identity := ""
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var animation:AnimationPlayer
var cow_solver:Node
var phase:=0.0

func _ready()->void:
	add_to_group("draft_animals")
	collision_layer=1;collision_mask=1;floor_snap_length=.4
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.8,1.65,2.1);shape.shape=box;shape.position.y=.85;add_child(shape)
	var handle=preload("res://animals/draft_animal_handle.gd").new();handle.animal=self;handle.name="LeadHandle";handle.position=Vector3(.6,1,0)
	var touch:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.15;touch.shape=sphere;handle.add_child(touch);add_child(handle)

func build()->void:
	model=load("res://assets/animals/cow/household_cow.glb" if kind=="bullock" else "res://assets/animals/horse/horse_body_refinement.glb").instantiate();add_child(model)
	if kind=="horse":model.scale=Vector3.ONE*.47;model.rotation.y=PI
	else:
		preload("res://animals/cow_visual.gd").apply(model)
		for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if "udder" in str(mesh.name).to_lower() or "teat" in str(mesh.name).to_lower():mesh.hide()
	animation=model.find_child("AnimationPlayer",true,false)
	vitality=load("res://animals/bullock_vitality.gd" if kind=="bullock" else "res://horses/horse_vitality.gd").new();add_child(vitality);vitality.configure(self,model,animation,Vector3.ZERO)
	vitality.died.connect(_died)
	_setup_motion()

func adopt(figure:Node3D,health:Node)->void:
	model=figure;vitality=health;model.reparent(self,true);vitality.reparent(self,true)
	vitality.hit_body.reparent(self,true);vitality.host=self
	animation=model.find_child("AnimationPlayer",true,false)
	vitality.died.connect(_died)
	_setup_motion()

func _died()->void:
	leader=null
	settle_corpse.call_deferred()
	if is_instance_valid(team):team.detach_animal(self)

func _physics_process(delta:float)->void:
	if team!=null or vitality==null or vitality.dead:return
	var speed:=0.0
	if is_instance_valid(leader) and leader.health>0 and not leader.has_meta("mounted_vehicle"):
		var target:Vector3=leader.global_position+leader.global_basis.z*2.0
		var offset:=target-global_position;offset.y=0
		if offset.length()>1:
			speed=minf(1.4,offset.length());velocity=offset.normalized()*speed;rotation.y=rotate_toward(rotation.y,atan2(-offset.x,-offset.z),delta*2)
		else:velocity.x=0;velocity.z=0
	else:velocity.x=0;velocity.z=0
	velocity.y-=18*delta;move_and_slide()
	if cow_solver!=null:
		cow_solver.update_breathing(delta,speed>.1);phase=fmod(phase+speed*delta/.72,1)
		for bone in cow_solver.rest:cow_solver.rig.set_bone_pose_rotation(bone,cow_solver.rest[bone])
		for tag in cow_solver.ORDER:
			var t:float=fmod(phase+cow_solver.OFFSETS[tag],1)
			var foot:Vector3=cow_solver.rig.to_global(cow_solver.rig.get_bone_global_rest(cow_solver.feet[tag][2]).origin)
			foot+=global_basis.z*sin(t*TAU)*.15 if speed>.1 else Vector3.ZERO
			foot.y=global_position.y+.076+(maxf(0,sin(t*TAU))*.08 if speed>.1 else 0.0)
			cow_solver._solve_leg(cow_solver.feet[tag],foot)
	if animation!=null:
		var clip:="AnimalArmature|Walk" if speed>.1 else "AnimalArmature|Idle"
		if animation.has_animation(clip) and animation.current_animation!=clip:animation.play(clip,.2)

func can_lead()->bool:
	return team==null and vitality!=null and not vitality.dead

func settle_corpse()->void:
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():return
	var shape:CollisionShape3D=get_child(0)
	var box:=BoxShape3D.new();box.size=Vector3(1.65,.60,2.7);shape.shape=box;shape.position=Vector3(vitality.fall_side*.4,.3,0)

func _setup_motion()->void:
	if kind!="bullock":return
	cow_solver=preload("res://animals/cow_motion.gd").new();cow_solver.configure(self,model);model.add_child(cow_solver);cow_solver.set_physics_process(false)
