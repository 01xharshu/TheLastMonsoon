extends Node
## World-scoped, bounded civilian sight and shared expression geometry cache.
const Expressions = preload("res://story/dialogue_expression.gd")
var viewer: Node3D
var equipment: Node
var player_visual: Node
var age := 0.0
var sense_age := 0.0
var near: Array[Node3D] = []
var faces := {}
var mesh_cache := {}
var last_incident := {}
var last_velocity := Vector3.ZERO
var activity_observers: Array[Node] = []

func _ready() -> void:
	name="CivilianAwareness"
	viewer=get_parent().get_node_or_null("Player")
	player_visual=viewer.get_node_or_null("VisualRoot/CharacterVisual") if viewer!=null else null
	if player_visual!=null:equipment=player_visual.get("equipment")
	for owner in get_tree().get_nodes_in_group("civilian_activity_observers"):
		if get_parent().is_ancestor_of(owner):activity_observers.append(owner)

func _process(delta: float) -> void:
	age+=delta;sense_age-=delta
	if sense_age<=0:
		sense_age=.25;near.clear()
		if equipment==null and is_instance_valid(player_visual):equipment=player_visual.get("equipment")
		for reaction in get_tree().get_nodes_in_group("civilian_reactions"):
			if not get_parent().is_ancestor_of(reaction) or not reaction.eligible():continue
			var actor: Node3D=reaction.actor
			if not is_instance_valid(viewer) or actor.global_position.distance_squared_to(viewer.global_position)>6400:continue
			near.append(actor)
			if threatening(viewer,actor) and visible(actor,viewer):reaction.witness(viewer,true)
		for owner in activity_observers:
			if not is_instance_valid(owner):continue
			for woman: Node3D in owner.women:
				if is_instance_valid(viewer) and threatening(viewer,woman) and visible(woman,viewer):owner.witness(viewer,true);break
	var constructed:=false
	for actor in near:
		if not is_instance_valid(actor) or actor.get_meta("dead",false):continue
		var speaking: bool=(actor.get_meta("speaking",false) or actor.get_meta("street_action","")=="talking") and not actor.get_meta("civilian_reacting",false)
		var fear: float=actor.get_meta("fear",0.0)
		# Work actors use authored Blender expressions and their local controller.
		if actor.has_method("perform"):continue
		var key:=actor.get_instance_id()
		if not faces.has(key):
			if constructed or (not speaking and fear<=0):continue
			faces[key]=configure_face(actor);constructed=true
		var expr: RefCounted=faces[key]
		expr.apply(fear,0,.65 if actor.get_meta("social_tone","")=="argument" else 0.0,Expressions.speech_weight(fposmod(age,8.0),8.0) if speaking else 0.0,Expressions.blink_weight(age,float(key%13)*.37),float(actor.get_meta("social_warmth",0.0)) if fear<=0 else 0.0)

func _physics_process(_delta: float) -> void:
	# Only actual contact results are inspected at physics cadence; sight and
	# population scans keep their bounded schedule above.
	if not is_instance_valid(viewer) or not viewer is CharacterBody3D:return
	for index in viewer.get_slide_collision_count():
		var hit: Object=viewer.get_slide_collision(index).get_collider()
		if hit is Node and hit.get_parent() is Node3D:
			var actor: Node3D=hit.get_parent()
			var reaction:=actor.get_node_or_null("CivilianReaction")
			if reaction!=null:reaction.impact(last_velocity.length(),viewer)
	last_velocity=viewer.velocity

func configure_face(actor: Node3D) -> RefCounted:
	var expr:=Expressions.new()
	var missing:=false
	for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if node.mesh is ArrayMesh and node.mesh.get_blend_shape_count()==0 and "body" in str(node.name).to_lower() and not mesh_cache.has(node.mesh.get_instance_id()):missing=true
	if missing:
		expr.configure(actor)
		for entry in expr.entries:mesh_cache[entry.source.get_instance_id()]=entry.node.mesh
	else:
		for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if mesh_cache.has(node.mesh.get_instance_id()):
				var source: Mesh=node.mesh;node.mesh=mesh_cache[source.get_instance_id()];expr.entries.append({"node":node,"source":source})
	return expr

func threatening(threat: Node3D, observer: Node3D) -> bool:
	if threat!=viewer or equipment==null or equipment.get("stowed")!=false:return false
	var offset:=observer.global_position-viewer.global_position
	if offset.length_squared()>144:return false
	var aiming: bool=equipment.get("aiming")==true
	var melee: bool=int(equipment.get("selected")) in [0,4]
	if not aiming and (not melee or offset.length_squared()>9):return false
	var camera:=viewer.get_viewport().get_camera_3d()
	if camera==null:return false
	return -camera.global_basis.z.dot(offset.normalized())>.65

func visible(observer: Node3D, threat: Node3D) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(observer.global_position+Vector3.UP*1.25,threat.global_position+Vector3.UP*1.1,1)
	var excluded: Array[RID]=[]
	var observer_body:=observer.get_node_or_null("BodyCollider") as CollisionObject3D
	var threat_body:=threat.get_node_or_null("BodyCollider") as CollisionObject3D
	if observer_body!=null:excluded.append(observer_body.get_rid())
	if threat_body!=null:excluded.append(threat_body.get_rid())
	if threat is CollisionObject3D:excluded.append(threat.get_rid())
	query.exclude=excluded
	return observer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func incident(victim: Node3D, threat: Node3D, armed: bool) -> void:
	if not is_instance_valid(threat):return
	var id:=victim.get_instance_id()
	if age-float(last_incident.get(id,-10.0))<.4:return
	last_incident[id]=age
	for reaction in get_tree().get_nodes_in_group("civilian_reactions"):
		if not get_parent().is_ancestor_of(reaction) or not reaction.eligible():continue
		var actor: Node3D=reaction.actor
		if actor==threat or actor.global_position.distance_squared_to(victim.global_position)>225:continue
		if actor!=victim and not visible(actor,victim):continue
		reaction.witness(threat,armed,actor==victim)
	for owner in activity_observers:
		if not is_instance_valid(owner):continue
		for woman: Node3D in owner.women:
			if woman.global_position.distance_squared_to(victim.global_position)<=225 and visible(woman,victim):owner.witness(threat,armed);break


func argument(first: Node3D, second: Node3D) -> void:
	if not is_instance_valid(first) or not is_instance_valid(second):return
	for reaction in get_tree().get_nodes_in_group("civilian_reactions"):
		if not get_parent().is_ancestor_of(reaction) or not reaction.eligible():continue
		var observer:Node3D=reaction.actor
		if observer==first or observer==second or observer.global_position.distance_squared_to(first.global_position)>100:continue
		if visible(observer,first):reaction.witness(first,false)


func settle_face(actor: Node3D) -> void:
	var key:=actor.get_instance_id()
	if not faces.has(key):faces[key]=configure_face(actor)
	faces[key].apply(0.0,0.0,0.0,0.0,1.0)
	for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for label in ["activity_speech","activity_fear","activity_blink"]:
			var index:=mesh.find_blend_shape_by_name(label)
			if index>=0:mesh.set_blend_shape_value(index,1.0 if label=="activity_blink" else 0.0)
