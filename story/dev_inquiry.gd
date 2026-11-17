extends Node3D
## Saved main-story inquiry. Chacha is independent optional exploration dialogue.
const Prompt=preload("res://story/dev_inquiry_prompt.gd")
const Official=preload("res://story/dev_inquiry_official.gd")
const FaceExpression=preload("res://story/dialogue_expression.gd")
const POLICE_LINES := [
	["Arjun","My brother Dev serves as a sepoy. There has been no word from him. Can you help me?",6.5],
	["Station officer","There is no answer for you here. You cannot expect us to find every absent sepoy.",6.5],
	["Arjun","Then let me speak to your superior.",4.0],
	["Station officer","The district officer is in the west chamber. Ask him yourself.",5.0]]
const OFFICE_LINES := [
	["District officer","Come in. So you are the man asking about Dev?",5.0],
	["Arjun","He is my brother. I only ask that you tell me what has happened to him.",5.5],
	["First official","Perhaps your brave brother ran away when there was work to do.",5.0],
	["Second official","And now his brother comes here expecting us to search for him!",5.0],
	["District officer","A fine family of heroes. Shall we stop our work for your brother?",5.5],
	["Arjun","You know nothing about him. Do not dishonour my brother to amuse yourselves.",6.0],
	["District officer","You dare speak to us like that? Soldiers! Come inside. Take him away.",6.0]]
var stage := "dormant"
var world: Node3D
var player: CharacterBody3D
var station: Node3D
var officials: Array[Node3D]=[]
var guards: Array[Node3D]=[]
var guard_paths: Array[PackedVector3Array]=[]
var expressions: Array[RefCounted]=[]
var player_expression: RefCounted
var actor_physics := true
var previous_busy := false
var lines: Array=[]
var line_index := 0
var line_age := 0.0
var dialogue := ""
var summon_age := 0.0
var second_return_path := PackedVector3Array()
var return_started := false
var subtitle: Label
var objective: Label
var objective_marker: Label
var destination: Node3D
var police_prompt: Node3D
var drawer_prompt: Node3D
var office_drawer: Node3D
var drawer_pistol: Node3D
var drawer_slide: Tween
var drawer_open := false
var drawer_looted := false
var officials_reassigned := false

var office_prompt: Node3D
var coordinator: Node
var configured := false
func _ready() -> void:
	name="DevInquiry";world=get_parent();player=world.get_node("Player")
	call_deferred("configure")
func configure() -> void:
	station=world.find_child("DistrictPolice",true,false)
	if station==null:push_error("Dev inquiry needs DistrictPolice");return
	coordinator=station.get_node("ThanaStaff/ArrestCoordinator")
	var roster=Node3D.new();roster.name="InquiryPersonnel";station.add_child(roster)
	for record in [["DistrictOfficer",Vector3(-9.5,-.48,-8.3)],["FirstOfficial",Vector3(-11.4,-.48,-5.8)],["SecondOfficial",Vector3(-7.7,-.48,-5.8)]]:
		var actor=Official.new();actor.name=record[0];actor.position=record[1]
		actor.rotation.y=0 if officials.is_empty() else PI
		actor.set_meta("inquiry_seat",actor.transform)
		var center: Vector3=record[1]+Vector3(0,.48,0)
		if officials.is_empty():
			preload("res://world/suryagarh/settlements/police_refinement.gd").chair(station,center,PI,true)
		else:
			station.piece(station,"InquiryBenchSeat",center+Vector3(0,.46,0),Vector3(.72,.08,.55),station.wood)
			for side in [-1,1]:station.piece(station,"InquiryBenchLeg",center+Vector3(side*.27,.22,0),Vector3(.065,.44,.45),station.wood,false)
		actor.add_child(preload("res://characters/npcs/british/official_man.glb").instantiate())
		roster.add_child(actor);officials.append(actor)
		var expression=FaceExpression.new();expression.configure(actor);expressions.append(expression)
	for i in 4:
		var actor=preload("res://story/dev_inquiry_guard.gd").new()
		actor.name="InquiryGuard%d"%i
		actor.position=[Vector3(-3,0,20),Vector3(3,0,20),Vector3(-3,0,-4.2),Vector3(-3,0,-9.4)][i]
		actor.set_meta("inquiry_post",actor.position)
		actor.rotation.y=PI if i<2 else -PI/2
		actor.set_meta("combat_faction","british");actor.set_meta("story_guard",true)
		actor.add_child(preload("res://characters/npcs/british/private_man.glb").instantiate())
		roster.add_child(actor);guards.append(actor)
		var duty:=preload("res://world/suryagarh/military_duty.gd").new()
		duty.name="StationGuardDuty";duty.inquiry=self
		duty.duty="station_sentry" if i<2 else "station_interior_round"
		var start:Vector3=actor.position
		duty.points=PackedVector3Array([station.to_global(start),station.to_global(start+Vector3(0,0,4 if i<2 else 3))])
		duty.wait=float(i)*2.0
		actor.add_child(duty)
	police_prompt=make_prompt("police","Ask about Dev",Vector3(8.3,.9,8),station.get_node("ThanaStaff/Daroga"))
	office_prompt=make_prompt("superior","Speak to the district officer",Vector3(-9.5,.9,-5.2),officials[0])
	var senior_desk: Node3D = station.get_meta("senior_office_desk",null)
	if is_instance_valid(senior_desk):
		office_drawer = senior_desk.get_node("MissionDrawer")
		drawer_prompt = make_prompt("office_drawer","Open the officer's drawer",Vector3(-8.72,.48,-7.84),officials[0])
		drawer_prompt.interaction_max_distance = 1.35
		drawer_pistol = preload("res://environment/weapons/adams_1851/adams_1851.glb").instantiate()
		office_drawer.add_child(drawer_pistol)
		# The revolver's barrel follows local X. Lay the complete mesh flat.
		drawer_pistol.rotation.x = PI/2
		var bounds := AABB()
		var first_mesh := true
		for mesh: MeshInstance3D in drawer_pistol.find_children("*","MeshInstance3D",true,false):
			var local_bounds := office_drawer.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = local_bounds if first_mesh else bounds.merge(local_bounds)
			first_mesh = false
		drawer_pistol.position = Vector3(-bounds.get_center().x,.036-bounds.position.y,.15-bounds.get_center().z)
		drawer_pistol.visible = not drawer_looted
	destination=Node3D.new();destination.name="DevInquiryDestination";world.add_child(destination)
	var layer=CanvasLayer.new();layer.layer=35;add_child(layer)
	subtitle=Label.new();layer.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left=90;subtitle.offset_right=-90;subtitle.offset_top=-135;subtitle.offset_bottom=-45
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size",23);subtitle.add_theme_constant_override("outline_size",6);subtitle.hide()
	objective=Label.new();layer.add_child(objective);objective.position=Vector2(24,32)
	objective.add_theme_font_size_override("font_size",21);objective.add_theme_constant_override("outline_size",5)
	objective_marker=Label.new();layer.add_child(objective_marker);objective_marker.add_theme_font_size_override("font_size",20);objective_marker.add_theme_constant_override("outline_size",5)
	configured=true;refresh_objective()
func make_prompt(id: String,text: String,at: Vector3,attendant: Node3D) -> Node3D:
	var prompt=Prompt.new();prompt.name=id.capitalize()+"Inquiry";prompt.action_id=id;prompt.sequence=self
	prompt.position=at;prompt.interaction_text=text;prompt.marker_height=.5
	prompt.set_meta("attendant",attendant);station.add_child(prompt);return prompt
func begin() -> void:
	if stage!="dormant":return
	stage="police";refresh_objective()
func can_request(id: String) -> bool:
	if not configured or not dialogue.is_empty() or player.health<=0:return false
	if id=="office_drawer":return drawer_available()
	if (id=="police" and stage!="police") or (id=="superior" and stage!="superior"):return false
	var attendant: Node3D=police_prompt.get_meta("attendant") if id=="police" else officials[0]
	return not attendant.get_meta("dead",false) and not attendant.get_meta("knocked_out",false)
func request(id: String,actor: CharacterBody3D) -> bool:
	if actor!=player or not can_request(id) or not player.get_node("CombatInput").available():return false
	if id=="office_drawer":return use_office_drawer()
	var director: Node=world.get_node_or_null("DevStory")
	if director!=null:return director.start_inquiry(id)
	if get_tree().root.get_node("SaveManager").police_case_active(player):return false
	if player.get_meta("detention_action","")!="" or player.get_meta("document_busy",false):return false
	if not player.is_on_floor():return false
	actor_physics=player.is_physics_processing();previous_busy=player.get_meta("document_busy",false)
	player.set_meta("document_busy",true);player.set_physics_process(false);player.velocity=Vector3.ZERO
	dialogue=id;lines=POLICE_LINES if id=="police" else OFFICE_LINES;line_index=0;line_age=0
	player_expression=FaceExpression.new();player_expression.configure(player.get_node("VisualRoot/CharacterVisual"))
	subtitle.show();show_line();return true
func drawer_available() -> bool:
	if not is_instance_valid(office_drawer) or drawer_looted or stage!="released":
		return false
	var director := world.get_node_or_null("DevStory")
	if director==null or director.state!="farm" or director.active:
		return false
	if player.get_meta("story_cinematic",false) or player.get_meta("document_busy",false):
		return false
	for person in get_tree().get_nodes_in_group("combat_actors")+officials:
		if person==player or not person is Node3D or not person.is_visible_in_tree():
			continue
		if person.get_meta("dead",false) or person.get_meta("knocked_out",false):
			continue
		var local := station.to_local(person.global_position)
		if local.x < -6.0 and local.x > -13.0 and local.z > -12.0 and local.z < -2.0 and absf(local.y)<2.0:
			return false
	return true

func use_office_drawer() -> bool:
	if player.global_position.distance_to(drawer_prompt.global_position)>drawer_prompt.interaction_max_distance:
		return false
	if not drawer_open:
		drawer_open = true
		drawer_slide = create_tween()
		drawer_slide.tween_property(office_drawer,"position:z",-.74,.35).set_trans(Tween.TRANS_SINE)
		drawer_prompt.interaction_text = "Take the Adams revolver"
		return true
	if office_drawer.position.z > -.73:
		return false
	if not player.inventory.add_item("pistol"):
		return false
	drawer_looted = true
	drawer_pistol.hide()
	return true

func update_office_assignment() -> void:
	if stage=="released" and not officials_reassigned:
		officials_reassigned = true
		for i in officials.size():
			var official: Node3D = officials[i]
			if official.get_meta("dead",false) or official.get_meta("knocked_out",false):
				continue
			official.position = Vector3(-11.6+float(i)*1.4,station.floor_y,-9.6)
			official.seated = false
			official.seat_weight = 0.0
			official.foot_plant.clear()
	elif stage!="released" and officials_reassigned:
		officials_reassigned = false
		for official in officials:
			if official.get_meta("dead",false) or official.get_meta("knocked_out",false):
				continue
			official.transform = official.get_meta("inquiry_seat")
			official.seated = true
			official.seat_weight = 1.0
			official.foot_plant.clear()

func show_line() -> void:
	var speaker: String=lines[line_index][0]
	subtitle.text=speaker+": "+str(lines[line_index][1])
	for i in officials.size():
		officials[i].speaking=speaker==["District officer","First official","Second official"][i]
		officials[i].attitude="mocking" if dialogue=="superior" and line_index in [2,3,4] else "neutral"
		expressions[i].apply(0,1.0 if officials[i].attitude=="mocking" else 0.0)
	if player_expression!=null:
		var angry: bool=dialogue=="superior" and line_index>=5
		player_expression.apply(.0 if angry else (.85 if speaker=="Arjun" else .4),0,.8 if angry else .0)
func _process(delta: float) -> void:
	if not configured:return
	update_office_assignment()
	if not dialogue.is_empty():
		if player.health<=0 or any_official_unavailable():cancel_dialogue();return
		var attendant: Node3D=police_prompt.get_meta("attendant") if dialogue=="police" else officials[0]
		preload("res://story/conversation_facing.gd").pair(player,attendant)
		if dialogue=="superior":
			for official in officials:preload("res://story/conversation_facing.gd").toward(official,player.global_position)
		line_age+=delta
		while not dialogue.is_empty() and line_age>=float(lines[line_index][2]):
			line_age-=float(lines[line_index][2]);line_index+=1
			if line_index==lines.size():finish_dialogue()
			else:show_line()
	if stage=="summoning":summon_age+=delta
	if stage=="punishment" and coordinator.phase in ["idle","return"] and player.get_meta("detention_action","")=="":
		stage="released";refresh_objective()
	if stage=="released" and not return_started:
		return_started=true
		second_return_path=coordinator.path(guards[3].global_position,station.to_global(guards[3].get_meta("inquiry_post")),.29)
	var hidden: bool=player.get_meta("morning_tutorial_active",false) or player.get_meta("opening_active",false) or player.get_meta("map_open",false) or player.inventory_ui.is_open()
	objective.visible=not hidden and stage not in ["dormant","summoning","punishment"] and dialogue.is_empty()
	objective_marker.visible=objective.visible and stage in ["police","superior"]
	var director: Node=world.get_node_or_null("DevStory")
	if director!=null and (director.active or director.state in ["farm","complete"]):
		objective.hide()
		objective_marker.visible=not hidden and not director.active
	objective_marker.hide() # DestinationMarker is the sole projected guidance owner.
	objective.hide()
	if objective_marker.visible:
		var camera: Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
		var target:=destination.global_position+Vector3.UP*1.3
		var pixel:=camera.unproject_position(target)
		var viewport:=get_viewport().get_visible_rect().size
		pixel.x=clampf(pixel.x,40,viewport.x-190);pixel.y=clampf(pixel.y,155,viewport.y-180)
		if camera.is_position_behind(target):pixel=Vector2(viewport.x*.5,155)
		objective_marker.position=pixel
		objective_marker.text="◆ %.0f m%s"%[player.global_position.distance_to(destination.global_position)," · turn around" if camera.is_position_behind(target) else ""]
func any_official_unavailable() -> bool:
	if dialogue!="superior":return false
	for actor in officials:
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):return true
	return false
func finish_dialogue() -> void:
	var was:=dialogue;dialogue="";subtitle.hide();reset_acting()
	if was=="police":
		unlock_player();stage="superior";refresh_objective()
	else:
		stage="summoning";summon_age=0
		subtitle.text="District officer: Take him away. Let him learn the cost of speaking out.";subtitle.show()
		guard_paths.clear()
		for i in 2:
			var goal:=player.global_position+Vector3(-.85 if i==0 else .85,-.9,0)
			guard_paths.append(coordinator.path(guards[i+2].global_position,goal,.29))
		refresh_objective()
func _physics_process(delta: float) -> void:
	if configured and stage=="released" and not second_return_path.is_empty():
		var guard: Node3D=guards[3]
		if guard.get_meta("dead",false) or guard.get_meta("knocked_out",false):second_return_path.clear();return
		var offset:=second_return_path[0]-guard.global_position;offset.y=0
		if offset.length()<.09:second_return_path.remove_at(0);guard.travel_speed=0;return
		var step:=offset.normalized()*minf(offset.length(),delta*1.3)
		if not guard._patrol_body_blocked(step):guard.global_position+=step;guard.travel_speed=1.3
		else:guard.travel_speed=0
		guard.rotation.y=lerp_angle(guard.rotation.y,atan2(offset.x,offset.z),minf(delta*5,1))
		return
	if stage!="summoning" or not configured:return
	var arrived:=0
	for i in 2:
		var guard: Node3D=guards[i+2]
		if guard.get_meta("dead",false) or guard.get_meta("knocked_out",false):cancel_dialogue();return
		var path: PackedVector3Array=guard_paths[i]
		if path.is_empty():
			if guard.global_position.distance_to(player.global_position-Vector3.UP*.9)<1.25:arrived+=1
			else:guard_paths[i]=coordinator.path(guard.global_position,player.global_position+Vector3(-.85 if i==0 else .85,-.9,0),.29)
			guard.travel_speed=0;continue
		var offset:=path[0]-guard.global_position;offset.y=0
		if offset.length()<.09:path.remove_at(0);guard_paths[i]=path;continue
		var step:=offset.normalized()*minf(offset.length(),delta*1.3)
		if not guard._patrol_body_blocked(step):guard.global_position+=step;guard.travel_speed=1.3
		else:guard.travel_speed=0
		guard.rotation.y=lerp_angle(guard.rotation.y,atan2(offset.x,offset.z),minf(delta*5,1))
	if arrived==2:
		unlock_player()
		if coordinator.accept_external_arrest(player,guards[2]):
			coordinator.home=station.to_global(guards[2].get_meta("inquiry_post"))
			coordinator.reason="story_order";stage="punishment";subtitle.hide();refresh_objective()
		else:cancel_dialogue()
	elif summon_age>30:cancel_dialogue()
func reset_acting() -> void:
	for i in officials.size():officials[i].speaking=false;officials[i].attitude="neutral";expressions[i].apply(0,0)
	if player_expression!=null:player_expression.restore();player_expression=null
func unlock_player() -> void:
	player.set_meta("document_busy",previous_busy);player.set_physics_process(actor_physics);player.velocity=Vector3.ZERO
func cancel_dialogue() -> void:
	dialogue="";subtitle.hide();reset_acting();unlock_player()
	for guard in guards:guard.travel_speed=0
	if stage=="summoning":stage="superior"
	refresh_objective()
func refresh_objective() -> void:
	if not configured:return
	destination.set_meta("parking_label","")
	match stage:
		"police":
			objective.text="Find Dev · Ask at the police station"
			destination.global_position=police_prompt.global_position
			destination.set_meta("parking_label","Find Dev · Police inquiry")
		"superior":
			objective.text="Find Dev · Speak to the superior in the west chamber"
			destination.global_position=office_prompt.global_position
			destination.set_meta("parking_label","Find Dev · Superior’s chamber")
		"released":objective.text="Find Dev · The officials refused to help. Explore for another lead."
		_:objective.text=""
func export_state() -> Dictionary:
	return {"stage":stage,"office_drawer_looted":drawer_looted}
func restore_state(data: Dictionary) -> void:
	drawer_looted = bool(data.get("office_drawer_looted",false))
	drawer_open = false
	if is_instance_valid(drawer_slide):drawer_slide.kill()
	if is_instance_valid(office_drawer):
		office_drawer.position.z = -.43
		drawer_pistol.visible = not drawer_looted
		drawer_prompt.interaction_text = "Open the officer's drawer"
	var saved: String=str(data.get("stage","dormant"))
	stage=saved if saved in ["dormant","police","superior","released"] else "superior"
	return_started=false;second_return_path.clear()
	refresh_objective()
func _exit_tree() -> void:
	if player_expression!=null:player_expression.restore()
	for expression in expressions:expression.restore()
