extends SceneTree
## Behavior/contact regression in a small physical arena; full-world checks separate.
const Policy=preload("res://combat/damage_policy.gd")
var errors: Array[String]=[]
var world: Node3D
var player: CharacterBody3D
var british: Node3D
var indian: Node3D
var visual: Node3D
var camera: Camera3D
var captures:=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:errors.append(label)
func make_actor(label: String, model: String, at: Vector3, faction: String) -> Node3D:
	var actor:=preload("res://characters/npcs/households/household_npc_actor.gd").new()
	actor.name=label;actor.position=at;actor.movement_enabled=false;actor.foot_plant_enabled=false
	actor.set_meta("combat_faction",faction)
	actor.add_child(load(model).instantiate());world.add_child(actor)
	return actor
func snap(label: String) -> void:
	if not captures:return
	for i in 2:await process_frame
	RenderingServer.force_draw(false, 1.0/60.0)
	root.get_texture().get_image().save_png("res://docs/characters/arjun/combat_%s_2026-10-05.png"%label)
func run() -> void:
	world=Node3D.new();root.add_child(world);current_scene=world
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var floor_mesh:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;floor_mesh.mesh=mesh;floor_mesh.position.y=-.1;floor.add_child(floor_mesh)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);world.add_child(light)
	player=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player);player.position=Vector3(0,.9,0)
	visual=player.get_node("VisualRoot/CharacterVisual")
	british=make_actor("Enemy","res://characters/npcs/british/private_man.glb",Vector3(0,0,1),"british")
	indian=make_actor("Peasant","res://characters/npcs/rescue_peasant.glb",Vector3(2,0,1),"indian")
	captures=DisplayServer.get_name()!="headless"
	if captures:
		root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		camera=Camera3D.new();camera.fov=45;world.add_child(camera);camera.position=Vector3(-2.5,1.7,4.0);camera.look_at(Vector3(.6,1,1));camera.make_current();player.get_node("UI").hide()
	for i in 8:await physics_frame
	player.set_physics_process(false)
	var vitality:=indian.get_node("Vitality")
	var enemy_vitality:=british.get_node("Vitality")
	check(not Policy.apply(indian.get_node("CombatHitBody"),100,player,"gun"),"civilian gun immunity")
	check(vitality.health==75,"protected civilian health unchanged")
	british.global_position=Vector3(2,0,3)
	await _physics_ticks(3)
	var ignore: Array[RID]=[player.get_rid()]
	var shot: Dictionary=preload("res://combat/ballistic_trace.gd").shoot(world.get_world_3d().direct_space_state,self,Vector3(2,1.15,-1),Vector3(2,1.15,5),50,ignore)
	check(not shot.is_empty() and vitality.health==75 and enemy_vitality.health==75,"real gun ray stops at civilian without crossfire damage")
	british.global_position=Vector3(0,0,1)
	await _physics_ticks(3)
	for kind in ["punch","kick","sword","weapon","takedown"]:check(not Policy.apply(indian.get_node("BodyCollider"),100,player,kind),"civilian protected from "+kind)
	check(Policy.apply(indian.get_node("BodyCollider"),28,british,"abuse"),"AI attack identity permits scripted civilian injury")
	check(indian.get_meta("last_attacker")==british and not vitality.dead,"AI attack source retained; civilian alive")
	check(enemy_vitality.receive_hit(12,player,"punch") and enemy_vitality.health==63,"British hit reduces health")
	var combat:=player.get_node("CombatInput")
	player.get_node("VisualRoot").global_rotation.y=0
	player.set_meta("combat_blocking",true)
	var old_health: float=player.health
	player.receive_combat_hit(10,british)
	check(is_equal_approx(player.health,old_health-2),"frontal guard absorbs 80 percent of melee damage")
	player.set_meta("combat_blocking",false)
	player.set_physics_process(true)
	check(combat.dodge(),"grounded stamina-cost dodge starts")
	combat._process(.5)
	check(not player.has_meta("combat_dodge"),"dodge completes and clears motion override")
	player.set_physics_process(false)
	visual.equipment.stowed=true
	for action in [0,1,2,3,5,6,7,9]:
		visual.motion_tree.active=true
		visual.motion_tree.set_melee(action,.45)
		visual.motion_tree.update_motion(.016,1.0,0.0,false,true)
		var bone: int=visual.skeleton.find_bone("upperarm_l" if action==1 else "upperarm_r" if action in [0,5,6] else "spine_01" if action==7 else "thigh_r")
		var contact: Quaternion=visual.skeleton.get_bone_pose_rotation(bone)
		visual.motion_tree.set_melee(action,0)
		visual.motion_tree.update_motion(.016,1.0,0.0,false,true)
		check(contact.angle_to(visual.skeleton.get_bone_pose_rotation(bone))>.15,"action "+str(action)+" actually deforms live tree")
	visual.motion_tree.set_melee(0,-1)
	await snap("standing")
	# Live process integration keeps the tree active throughout a kick.
	player.set_physics_process(true)
	combat.kick();combat._process(.23);visual._process(.016)
	check(visual.motion_tree.active and visual.motion_tree.get("parameters/melee/blend_amount")>0.99,"kick remains owned by AnimationTree")
	await snap("kick")
	combat.kick_time=-1;visual.kick_phase=-1;combat.kick_cooldown=0
	# NPC punch must physically overlap Arjun rather than damage solely by range.
	british.rotation.y=PI;british.combat_react("strike")
	var npc_contacts:=0
	for tick in 45:
		await physics_frame
		var hand_point: Vector3=british._skeleton.to_global(british._skeleton.get_bone_global_pose(british._skeleton.find_bone("hand_r")).origin)
		if tick==20:print("NPC FIST ",hand_point," player ",player.position)
		var q:=PhysicsShapeQueryParameters3D.new();var fist:=SphereShape3D.new();fist.radius=.14
		q.shape=fist;q.transform.origin=hand_point;q.collision_mask=1;q.exclude=[british.body_collider.get_rid()]
		for overlap in world.get_world_3d().direct_space_state.intersect_shape(q,8):
			if overlap.collider==player:npc_contacts+=1
	check(npc_contacts>0,"British strike reaches actual player capsule")
	british.rotation.y=0
	# Actual native action playback must contact the enemy body, not only set a timer.
	player.set_physics_process(true)
	player.position=Vector3(0,.9,0)
	var aim: Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
	player.set_process_input(false);player.set_process_unhandled_input(false)
	player.get_node("CameraPivot").rotation=Vector3(0,PI,0)
	aim.rotation=Vector3.ZERO
	enemy_vitality.health=75
	combat.punch()
	await _physics_ticks(30)
	print("PUNCH CONTACT POINT ",combat.last_melee_contact," health ",enemy_vitality.health)
	check(enemy_vitality.health==63,"native punch fist contacts actual enemy receiver once")
	combat.kick()
	await _physics_ticks(40)
	print("KICK CONTACT POINT ",combat.last_melee_contact," health ",enemy_vitality.health)
	check(enemy_vitality.health==43,"native kick boot contacts actual enemy receiver once")
	combat.punch()
	await _physics_ticks(30)
	check(enemy_vitality.health==31,"opposite fist contacts enemy once")
	british.position.z=2.2
	await _physics_ticks(3)
	combat.punch()
	await _physics_ticks(30)
	check(enemy_vitality.health==31,"punch misses enemy beyond visible reach")
	british.position.z=1
	await _physics_ticks(3)
	player.inventory.add_item("utility_knife",1)
	visual.equipment.selected=4;visual.equipment.stowed=false;visual.equipment._refresh()
	enemy_vitality.health=75
	var knife:=player.get_node("KnifeStrike")
	check(knife.strike(),"native knife action starts")
	for tick in 38:
		await physics_frame
		if tick==14:print("KNIFE EXTENSION ",visual.equipment.knife_blade_segment())
	print("KNIFE CONTACT health ",enemy_vitality.health," blade ",visual.equipment.knife_blade_segment())
	check(enemy_vitality.health==57,"visible knife blade contacts enemy once")
	player.inventory.add_item("talwar",1)
	visual.equipment.selected=0;visual.equipment._refresh()
	enemy_vitality.health=75
	check(player.get_node("TalwarSlash").strike(),"native sword action starts")
	await _physics_ticks(48)
	check(enemy_vitality.health==30,"sword damages actor once across multiple colliders")
	visual.equipment.stowed=true;visual.equipment._refresh()
	# Restore normal physics for the public rear-grapple availability contract.
	player.set_physics_process(true)
	player.position=Vector3(0,.9,.25);british.rotation.y=0
	for i in 3:await physics_frame
	var grapple:=player.get_node("RearGrapple")
	check(grapple.begin(),"rear grapple starts in reach behind enemy")
	for i in 24:await physics_frame
	var hold_error: float=grapple.contact_error
	print("HOLD CONTACT ",hold_error," root separation ",Vector2(player.position.x-british.position.x,player.position.z-british.position.z).length())
	check(hold_error<.03,"rear hold palms reach collar targets within 3 cm")
	check(grapple.active and player.get_meta("paired_combat",false),"paired hold locks player movement")
	if captures:
		grapple.set_process(false);grapple.set_physics_process(false);visual.set_process(false)
	await snap("rear_hold")
	if captures:
		grapple.set_process(true);grapple.set_physics_process(true);visual.set_process(true)
	grapple._process(1.3)
	check(british.get_meta("knocked_out",false) and not enemy_vitality.dead and not grapple.active,"rear hold ends in living knockout and releases controls")
	for i in 80:await physics_frame
	await snap("knockout")
	check(british.get_node("CombatMotion").state=="down","knockout settles in down tree state")
	var head: int=british._skeleton.find_bone("head")
	var head_y: float=british._skeleton.to_global(british._skeleton.get_bone_global_pose(head).origin).y

	check(head_y<.35,"fallen head is near physical floor")
	var down_bounds: Dictionary=preload("res://tools/characters/skinned_ground_audit.gd").bounds(british)
	var lowest:=INF
	for measured_bounds in down_bounds.values():lowest=minf(lowest,measured_bounds.minimum_y)
	check(lowest>=-.025 and lowest<.03,"fallen visible meshes meet floor without penetration")
	check(absf(enemy_vitality.torso_shape.global_basis.y.dot(Vector3.UP))<.35,"fallen torso receiver follows horizontal body")
	var body_ray:=PhysicsRayQueryParameters3D.create(enemy_vitality.torso_shape.global_position+Vector3.UP*1.2,enemy_vitality.torso_shape.global_position-Vector3.UP*.4,8)
	body_ray.exclude=[player.get_rid()]
	var body_hit:=world.get_world_3d().direct_space_state.intersect_ray(body_ray)
	check(not body_hit.is_empty() and Policy.receiver(body_hit.collider)==enemy_vitality,"fallen physical torso remains hittable")
	check(not player.get_node("TalwarSlash").is_processing() and not knife.is_processing(),"idle weapon controllers stop processing")
	check(not grapple.is_processing() and not grapple.is_physics_processing(),"completed rear restraint sleeps both update callbacks")

	check(vitality.receive_hit(100,british,"abuse") and indian.get_meta("knocked_out",false) and not vitality.dead,"civilian beating causes nonlethal fall")
	for i in 80:await physics_frame
	await snap("peasant_fall")
	var peasant_bounds: Dictionary=preload("res://tools/characters/skinned_ground_audit.gd").bounds(indian)
	var peasant_lowest:=INF
	for measured_bounds in peasant_bounds.values():peasant_lowest=minf(peasant_lowest,measured_bounds.minimum_y)
	print("PEASANT FLOOR MINIMUM ",peasant_lowest)
	check(peasant_lowest>=-.025 and peasant_lowest<.03,"fallen rescue peasant meets floor without penetration")
	check(enemy_vitality.receive_hit(35,player,"gun") and enemy_vitality.dead,"gun can kill a knocked-out enemy")
	var report={"rear_hold_target_error_m":hold_error,"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"fallen_head_y_m":head_y,"fallen_mesh_minimum_y_m":lowest,"peasant_mesh_minimum_y_m":peasant_lowest,"renderer":RenderingServer.get_current_rendering_method(),"visual_approved":false}
	var file:=FileAccess.open("res://docs/characters/arjun/combat_rescue_validation%s.json"%("_metal" if captures else ""),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT RESCUE ",report.status," ",errors)
	world.queue_free();await process_frame;await process_frame
	quit(0 if errors.is_empty() else 1)

func _physics_ticks(count: int) -> void:
	for i in count:await physics_frame
