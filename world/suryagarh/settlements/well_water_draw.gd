extends Node3D
## One shared rope and bucket; residents take turns at the existing village well.
var bucket:Node3D
var rope:Node3D
var roller:Node3D
var age:=0.0
var worker:Node
var next_worker:=""
var pull_rope:MeshInstance3D
var stream:MeshInstance3D

func configure(well:Node3D)->void:
	for label in ["SuspendedBucket","DrawRope","WaterRoller"]:
		var item:=well.get_node_or_null(label)
		if item!=null:item.reparent(self,true)
	bucket=get_node("SuspendedBucket");rope=get_node("DrawRope");roller=get_node("WaterRoller")
	pull_rope=MeshInstance3D.new();pull_rope.name="RopeToHands"
	var cord:=CylinderMesh.new();cord.top_radius=.009;cord.bottom_radius=.009;cord.height=1
	pull_rope.mesh=cord
	var fibre:=StandardMaterial3D.new();fibre.albedo_color=Color(.45,.32,.18);pull_rope.material_override=fibre
	add_child(pull_rope);pull_rope.hide()
	stream=MeshInstance3D.new();stream.name="DrawnWaterStream"
	var water:=CylinderMesh.new();water.top_radius=.014;water.bottom_radius=.018;water.height=1;stream.mesh=water
	var wet:=StandardMaterial3D.new();wet.albedo_color=Color(.23,.36,.39,.65);wet.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	stream.material_override=wet;add_child(stream);stream.hide()

func draw(activity:Node,delta:float)->bool:
	if worker!=null and (not is_instance_valid(worker) or worker.actor.get_meta("dead",false)):worker=null
	if worker==null:
		if not next_worker.is_empty() and str(activity.actor.name)!=next_worker:return false
		worker=activity;age=0
	if worker!=activity:return false
	age+=delta
	var lift:=clampf((age-2)/5,0,1)
	bucket.position=Vector3(0,lerpf(.28,1.18,lift),.15);bucket.rotation.x=0
	stream.hide()
	if age>=7:
		var poured:=clampf((age-7)/.65,0,1)
		var rim:Vector3=to_local(activity.actor.to_global(Vector3(-.35,1.20,.20)))
		bucket.position=bucket.position.lerp(rim,poured);bucket.rotation.x=poured*.45
		if age>=7.65 and age<8.7:
			stream.position=bucket.position-Vector3.UP*.50;stream.show()
			activity.actor.set_meta("daily_activity","filling_water_bucket")
	var top:=Vector3(0,2.37,.15);var bottom:=bucket.position+Vector3.UP*.40
	rope.position=(top+bottom)*.5;rope.scale.y=(top.y-bottom.y)/1.48
	roller.rotation.x=lift*TAU*2
	var local_grip:=Vector3(-.12,1.10+.035*sin(age*TAU),.36)
	var hand:Vector3=to_local(activity.actor.to_global(local_grip))
	pull_rope.position=(top+hand)*.5;pull_rope.scale.y=top.distance_to(hand)
	pull_rope.quaternion=Quaternion(Vector3.UP,(top-hand).normalized());pull_rope.show()
	activity.prop.position=Vector3(-.35,.08,.20)
	for side in ["r"]:
		var grip:Vector3=activity.actor.to_global(local_grip)
		activity.actor.solve_hand_contact(side,grip);activity.actor.set_grip(side,.45)
		activity.hand_error=maxf(activity.hand_error,activity.actor.palm_world(side).distance_to(grip))
	if age<7:activity.actor.set_meta("daily_activity","drawing_well_water")
	if age>=9:
		activity.actor.set_meta("water_draws",int(activity.actor.get_meta("water_draws",0))+1)
		for other in get_tree().get_nodes_in_group("village_work_residents"):
			if other!=activity.actor and other.get_node("DailyActivity").job=="well":next_worker=str(other.name);break
		worker=null;pull_rope.hide();stream.hide()
	return true
