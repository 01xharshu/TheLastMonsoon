extends Node3D
## Main-world cinematic story and interactive, persistent farm lessons.
const Pose=preload("res://story/story_pose.gd")
const LESSONS := [
 ["Draw your talwar and hold it at rest. Press 1.","talwar_idle"],
 ["Face the first practice partner and strike with your talwar. Use Attack.","sword"],
 ["Jump, then slash while airborne. Space + Attack.","jump_sword"],
 ["Equip the spear and hold it at rest. Press 7.","spear_idle"],
 ["Thrust at the second practice partner. Use Attack.","spear"],
 ["Jump and thrust with your spear. Space + Attack.","jump_spear"],
 ["Draw the dagger and strike the third practice partner. Press 5 + Attack.","knife"],
 ["Approach each consenting partner from behind, unarmed, and press Q to practise the knockout.","takedown"]]
var inquiry: Node
var player: CharacterBody3D
var visual: Node3D
var community: Node
var chacha: Node3D
var chacha_home:=Transform3D.IDENTITY
var pose=Pose.new()
var state:="awaiting_inquiry"
var first_chacha_seen:=false
var lesson:=0
var completed_partners: Array[int]=[]
var active:=false
var kind:=""
var beats: Array[Dictionary]=[]
var beat_index:=0
var age:=0.0
var cue:=""
var camera: Camera3D
var gameplay_camera: Camera3D
var shade: ColorRect
var caption: Label
var objective: Label
var bars: Array[ColorRect]=[]
var actor_physics:=true
var prior_busy:=false
var hud: Array[CanvasItem]=[]
var hidden_hud: Array[bool]=[]
var prior_chacha_process:=true
var camera_start:=Vector3.ZERO
var camera_end:=Vector3.ZERO
var camera_target:=Vector3.ZERO
var start_position:=Vector3.ZERO
var finish_position:=Vector3.ZERO
var idle_age:=0.0
var swing_age:=0.0
var journey_horse: Node3D
var horse_physics:=true
var hero_path:=PackedVector3Array()
var path_origin:=Vector3.ZERO
var tea_start:=Vector3.ZERO
var official_start:=Vector3.ZERO
var last_strike:=-1
var strike_contact_error:=INF
var collar_contact_error:=INF
var support_contact_error:=INF
var cup_contact_error:=INF
var tea_helper_contact_error:=INF
var carry_contact_error:=INF
var impact_clock:=10.0
var impact_direction:=Vector3.ZERO
var cup: MeshInstance3D
var demonstration_weapon: Node3D
var configured:=false
var entrance_paths: Array[PackedVector3Array]=[]
var hero_expression: RefCounted
var police_expression: RefCounted
var collar_cloth: RefCounted
var gear_snapshot: Dictionary={}
func _ready() -> void:
 name="DevStory";process_priority=90;call_deferred("configure")
func configure() -> void:
 inquiry=get_parent().get_node("DevInquiry");player=get_parent().get_node("Player")
 community=get_parent().get_node("StoryCommunity")
 chacha=get_parent().get_node("ChachaHouse/Chacha");chacha_home=chacha.global_transform
 visual=player.get_node("VisualRoot/CharacterVisual");pose.configure(visual)
 gameplay_camera=player.get_node("CameraPivot/SpringArm3D/Camera3D")
 camera=Camera3D.new();camera.name="StoryCamera";camera.fov=48;camera.near=.05;add_child(camera)
 var layer:=CanvasLayer.new();layer.layer=80;add_child(layer)
 shade=ColorRect.new();layer.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for top in [true,false]:
  var bar:=ColorRect.new();layer.add_child(bar);bar.color=Color.BLACK;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
  bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
  if top:bar.offset_bottom=72
  else:bar.offset_top=-125
  bars.append(bar);bar.hide()
 caption=Label.new();layer.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 caption.offset_left=70;caption.offset_right=-70;caption.offset_top=-115;caption.offset_bottom=-25
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size",23);caption.add_theme_constant_override("outline_size",5);caption.hide()
 objective=Label.new();layer.add_child(objective);objective.position=Vector2(32,140);objective.add_theme_font_size_override("font_size",21);objective.add_theme_constant_override("outline_size",5)
 var shape:=CylinderMesh.new();shape.top_radius=.055;shape.bottom_radius=.04;shape.height=.12
 cup=MeshInstance3D.new();cup.mesh=shape;var clay:=StandardMaterial3D.new();clay.albedo_color=Color(.43,.26,.16);cup.material_override=clay;add_child(cup);cup.hide()
 var tea:=MeshInstance3D.new();tea.name="TeaSurface";var liquid:=CylinderMesh.new();liquid.top_radius=.044;liquid.bottom_radius=.044;liquid.height=.004
 tea.mesh=liquid;var tea_mat:=StandardMaterial3D.new();tea_mat.albedo_color=Color(.18,.08,.03);tea_mat.roughness=.2;tea.material_override=tea_mat
 cup.add_child(tea);tea.position.y=.053
 configured=true;refresh()
func line(speaker: String,text: String,seconds: float,at: Vector3,target: Vector3,action:="",place:="station") -> Dictionary:
 return {"speaker":speaker,"text":text,"seconds":seconds,"at":at,"target":target,"cue":action,"place":place}
func begin_optional() -> bool:
 if not configured or active or first_chacha_seen or player.get_meta("document_busy",false):return false
 var list: Array[Dictionary]=[]
 for record in preload("res://world/suryagarh/settlements/chacha_advice.gd").LINES:
  list.append(line(record.speaker,record.text,record.seconds,Vector3(2,1.7,6),Vector3(-.85,1.3,3.3),"optional","house"))
 start("optional",list);return true
func start_horse_journey(horse: Node3D) -> bool:
 if not configured or active or horse.rider!=player or not horse.transition.is_empty():return false
 journey_horse=horse;horse_physics=horse.is_physics_processing()
 if not start_inquiry("horse"):
  journey_horse=null;return false
 return true
func start_inquiry(_id:="police") -> bool:
 if not configured or active or state!="awaiting_inquiry" or player.health<=0:return false
 if player.get_meta("document_busy",false) or get_tree().root.get_node("SaveManager").police_case_active(player):return false
 var list: Array[Dictionary]=[]
 if _id=="horse":
  list.append(line("","",4,Vector3.ZERO,Vector3.ZERO,"horse_departure","home"))
  list.append(line("","",4,Vector3(5,2.8,32),Vector3(0,1.4,25),"horse_arrival"))
  list.append(line("","",1.4,Vector3(3,1.8,25),Vector3(0,1,23),"horse_dismount"))
 list.append(line("","",12,Vector3(7,2.1,23),Vector3(0,1,18),"entry"))
 for record in inquiry.POLICE_LINES:
  list.append(line(record[0],record[1],record[2],Vector3(6,1.65,9.5),Vector3(8.6,1.3,7.4),"reception"))
 list.append(line("","",14,Vector3(-10.5,1.8,-3.2),Vector3(-9.5,1.2,-8),"chamber"))
 for i in inquiry.OFFICE_LINES.size():
  var record: Array=inquiry.OFFICE_LINES[i]
  if i==6:
   list.append(line("District officer","Mind your tongue. You are in a government office.",4.5,Vector3(-8,1.7,-4),Vector3(-9.5,1.4,-8),"warning"))
  else:
   list.append(line(record[0],record[1],record[2],Vector3(-8,1.7,-4),Vector3(-9.5,1.4,-8),"humiliation" if i<5 else "objection"))
 # Give the approach and physical escalation their own silent beat before the alarm.
 list.append(line("","",6,Vector3(-10.5,1.8,-3),Vector3(-7.8,1.3,-5.3),"collar"))
 list.append(line("District officer","Guards! Get him off me!",8,Vector3(-10.5,1.8,-4),Vector3(-5.5,1.15,-7),"guards"))
 list.append(line("Guard","Down!",7,Vector3(-11.8,2.8,-3.0),Vector3(-7.8,1.1,-4.6),"beating"))
 list.append(line("","",4,Vector3(-11.8,1.8,-2.0),Vector3(-7.8,.4,-4.6),"collapse"))
 list.append(line("Guard","Throw him outside. Let everyone see what comes of his insolence.",4,Vector3(4,1.4,27),Vector3(0,.35,25),"discard","station_exterior"))
 list.append(line("","",2.5,Vector3(3,1.1,29),Vector3(0,.5,26),"throw","station_exterior"))
 list.append(line("Chacha","Arjun! What have they done to you? Let me help you.",7,Vector3(-2.5,1.8,30),Vector3(.25,.8,27),"rescue","station_exterior"))
 list.append(line("","",4,Vector3(3,1.8,30),Vector3(0,1,29),"support_walk","station_exterior"))
 list.append(line("","",4,Vector3(-5.6,1.65,2.3),Vector3(-3.8,1.1,.3),"bed_arrival","house"))
 list.append(line("Chacha","Slowly. Sit up. I have brought you some tea.",5,Vector3(-5.6,1.65,2.3),Vector3(-3.8,1.1,.3),"bed_sit","house"))
 list.append(line("","",3,Vector3(-5.6,1.65,2.3),Vector3(-3.8,1.1,.3),"tea_offer","house"))
 list.append(line("Chacha","Drink this. Your body needs rest.",7,Vector3(-5.6,1.65,2.3),Vector3(-3.8,1.1,.3),"drink","house"))
 list.append(line("Chacha","Bare hands against armed men will only get you hurt. First heal. Then meet me at the farm. I will teach you.",8,Vector3(-5.6,1.65,2.3),Vector3(-3.8,1.1,.3),"heal","house"))
 inquiry.stage="cinematic";inquiry.refresh_objective();start("inquiry",list);return true
func start(which: String,list: Array[Dictionary]) -> void:
 active=true;kind=which;beats=list;beat_index=0;age=0;cue=""
 if which in ["inquiry","optional"]:
  hero_expression=preload("res://story/dialogue_expression.gd").new();hero_expression.configure(visual)
 if which=="inquiry":
  police_expression=preload("res://story/dialogue_expression.gd").new();police_expression.configure(inquiry.police_prompt.get_meta("attendant"))
  collar_cloth=preload("res://story/collar_cloth.gd").new();collar_cloth.configure(inquiry.officials[0])
 actor_physics=player.is_physics_processing();prior_busy=player.get_meta("document_busy",false)
 player.set_meta("document_busy",true);player.set_meta("story_cinematic",true);player.set_physics_process(false);player.velocity=Vector3.ZERO
 player.get_node("CombatInput").interrupt()
 gear_snapshot={"selected":visual.equipment.selected,"stowed":visual.equipment.stowed,"spear":player.get_node("ChachaKit").active}
 visual.equipment.stowed=true;visual.equipment._refresh();player.get_node("ChachaKit").active=false
 player.get_node("TalwarSlash").elapsed=.68;player.get_node("KnifeStrike").elapsed=-1
 visual.slash_phase=-1;visual.knife_phase=-1
 prior_chacha_process=chacha.is_processing();chacha.set_process(false);chacha.route.clear();chacha.travel_speed=0
 hud.clear();hidden_hud.clear()
 for path in ["HUD","LandscapeUI","Player/UI/HUDRoot","Player/InteractionUI"]:
  var node: Node=get_parent().get_node_or_null(path)
  if node is CanvasItem:hud.append(node);hidden_hud.append(node.visible);node.hide()
 for bar in bars:bar.show()
 caption.show();camera.current=true;objective.hide();enter_beat()
func enter_beat() -> void:
 age=0;var record: Dictionary=beats[beat_index]
 var previous:=cue;cue=record.cue
 caption.text=(record.speaker+": " if not record.speaker.is_empty() else "")+record.text
 var place: Node3D=inquiry.station if record.place in ["station","station_exterior"] else get_tree().get_first_node_in_group("arjun_home") if record.place=="home" else get_parent().get_node("ChachaHouse") if record.place=="house" else community.farm
 camera_start=place.to_global(record.at);camera_end=camera_start+place.global_basis.x*.22
 camera_target=place.to_global(record.target)
 if cue=="optional":
  camera_target=(player.global_position+chacha.global_position)*.5+Vector3.UP*.65
  camera_start=camera_target+chacha.global_basis.x*2.2+chacha.global_basis.z*2.5+Vector3.UP*.35
  camera_end=camera_start+chacha.global_basis.x*.22
 if cue!=previous:
  if beat_index==0 or beats[beat_index-1].place!=record.place:
   shade.color.a=1;create_tween().tween_property(shade,"color:a",0,.65)
  else:shade.color.a=0
  stage_action(cue)
 if cue in ["reception","humiliation","objection","warning"]:frame_conversation(record.speaker)
 camera.global_position=camera_start;camera.look_at(camera_target)
 for i in inquiry.officials.size():
  inquiry.officials[i].attention=player.global_position+Vector3.UP*.6
  inquiry.officials[i].speaking=record.speaker==["District officer","First official","Second official"][i]
  var mocking: bool=cue=="humiliation" and beat_index>0 and record.speaker!="Arjun" and inquiry.officials[i].speaking
  inquiry.officials[i].attitude="mocking" if mocking else "neutral"
  inquiry.expressions[i].apply(0,.45 if mocking else 0)
func frame_conversation(speaker: String) -> void:
 # Keep every reverse angle on the entrance side of the conversation axis.
 var station: Node3D=inquiry.station
 var subject: Node3D=player
 if speaker=="Station officer":subject=inquiry.police_prompt.get_meta("attendant")
 elif speaker in ["District officer","First official","Second official"]:
  subject=inquiry.officials[["District officer","First official","Second official"].find(speaker)]
 var focus: Vector3=subject.global_position+Vector3.UP*(.6 if subject==player else 1.6 if subject in inquiry.officials and subject.seated else 1.5)
 camera_target=focus
 var offset:=Vector3(1.65,.20,-2.7) if subject==player else Vector3(1.65,.20,2.7)
 camera_start=focus+station.global_basis*offset
 camera_end=camera_start+station.global_basis.x*.08
 camera.fov=48

func stage_action(action: String) -> void:
 for guard in inquiry.guards:guard.cinematic_style="";guard.cinematic_palms.clear();guard.cinematic_carry=false
 var station: Node3D=inquiry.station
 if action=="horse_departure":
  journey_horse.set_physics_process(false);journey_horse.pace=2.0
  start_position=journey_horse.global_position;finish_position=start_position-journey_horse.global_basis.z*8
  camera_start=start_position+journey_horse.global_basis.x*5+Vector3.UP*2.4;camera_end=camera_start-journey_horse.global_basis.z*3;camera_target=start_position+Vector3.UP*1.4
 elif action=="horse_arrival":
  journey_horse.set_physics_process(false);journey_horse.rotation.y=station.global_rotation.y
  start_position=station.to_global(Vector3(0,0,30));finish_position=station.to_global(Vector3(0,0,23.5))
  start_position.y=get_parent().layout.height(start_position.x,start_position.z)+.1
  finish_position.y=get_parent().layout.height(finish_position.x,finish_position.z)+.1
  journey_horse.global_position=start_position;journey_horse.pace=1.625
 elif action=="horse_dismount":
  journey_horse.pace=0;journey_horse.velocity=Vector3.ZERO;journey_horse.set_physics_process(true)
  if not journey_horse.dismount():
   # A physics tick establishes ground contact before the dismount request.
   journey_horse.set_meta("story_dismount_pending",true)
 elif action=="entry":
  var arrived_by_horse:=is_instance_valid(journey_horse)
  release_story_horse()
  if not arrived_by_horse:player.global_position=station.to_global(Vector3(0,.9,19))
  set_hero_path(station.to_global(Vector3(8.3,.9,9)))
 elif action=="reception":player.global_position=station.to_global(Vector3(8.3,.9,9));player.velocity=Vector3.ZERO;face(player,station.to_global(Vector3(9,1,6.8)))
 elif action=="chamber":set_hero_path(station.to_global(Vector3(-9.5,.9,-5.2)))
 elif action=="collar":
  inquiry.officials[0].seated=false
  official_start=inquiry.officials[0].global_position
  camera_start=station.to_global(Vector3(-10.5,1.8,-3));camera_end=camera_start+station.global_basis.x*.22;camera_target=station.to_global(Vector3(-7.8,1.3,-5.3))
  start_position=player.global_position;finish_position=station.to_global(Vector3(-7.8,.9,-4.82));face(player,inquiry.officials[0].global_position)
 elif action=="guards":
  entrance_paths.clear()
  for i in 4:
   var guard: Node3D=inquiry.guards[i]
   guard.global_position=station.to_global(Vector3(-3,0,[-4.2,-5.8,-8.8,-10.4][i]))
   var goal:=station.to_global(Vector3(-7.8+[-.85,.60,-.6,.6][i],0,-4.6+[.4,.4,-.5,-.5][i]))
   entrance_paths.append(inquiry.coordinator.path(guard.global_position,goal,.29))
   guard.duty_state="restraint";guard.travel_speed=0
  swing_age=0
 elif action=="beating":
  start_position=player.global_position;impact_clock=10.0;impact_direction=Vector3.ZERO
  inquiry.officials[0].global_position=station.to_global(Vector3(-10.5,0,-8.3))
  for i in 4:
   inquiry.guards[i].global_position=station.to_global(Vector3(-7.8+[-.85,.60,-.6,.6][i],0,-4.6+[.4,.4,-.5,-.5][i]))
   face(inquiry.guards[i],player.global_position);inquiry.guards[i].travel_speed=0
  swing_age=0;last_strike=-1
 elif action=="collapse":player.health=maxf(20,minf(player.health,25))
 elif action=="discard":
  start_position=station.to_global(Vector3(0,1.75,23));finish_position=station.to_global(Vector3(0,1.75,25))
  player.global_position=start_position;face(player,station.to_global(Vector3(0,1,29)))
 elif action=="throw":
  start_position=player.global_position;finish_position=station.to_global(Vector3(0,.9,27))
 elif action=="rescue":
  chacha.global_position=player.global_position+station.global_basis.x*.58-Vector3.UP*.9;face(chacha,player.global_position)
  reset_actor_grounding(chacha)
 elif action=="support_walk":
  start_position=player.global_position;finish_position=start_position+station.global_basis.z*2
  face(player,finish_position);face(chacha,finish_position+station.global_basis.x*.58)
  reset_actor_grounding(chacha)
 elif action=="bed_arrival":
  var bed: Node3D=get_parent().get_node("ChachaHouse/RecoveryBed/Charpai")
  player.global_position=bed.to_global(Vector3(0,.83,0));player.get_node("VisualRoot").global_basis=bed.global_basis
  player.set_meta("rest_action","sleep");player.set_meta("rest_progress",1.0)
  chacha.global_position=bed.to_global(Vector3(.55,0,.35));face(chacha,player.global_position)
 elif action=="bed_sit":
  player.set_meta("rest_waking",true)
  chacha.global_position=player.global_position+player.get_node("VisualRoot").global_basis*Vector3(.55,-.83,.35);face(chacha,player.global_position)
 elif action=="tea_offer":tea_start=cup.global_position
 elif action=="heal":player.health=player.MAX_HEALTH
 elif action=="demo":setup_demo()
func reset_actor_grounding(actor: Node3D) -> void:
 actor.foot_plant.clear()
 actor.foot_plant.reset_pose()
 for side in ["l","r"]:
  var foot: int=actor._bones["foot_"+side]
  actor.foot_plant.ankle_height[side]=actor._skeleton.to_global(actor._skeleton.get_bone_global_rest(foot).origin).y

func face(actor: Node3D,target: Vector3) -> void:
 var offset:=target-actor.global_position
 if actor==player:player.get_node("VisualRoot").global_rotation.y=atan2(offset.x,offset.z)
 else:actor.global_rotation.y=atan2(offset.x,offset.z)
func _process(delta: float) -> void:
 if not configured:return
 if not active and state=="awaiting_inquiry" and not player.get_meta("morning_tutorial_active",false) and inquiry.stage=="police":
  var mount: Node=player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null
  if mount!=null and str(mount.name)=="VillageHorse" and mount.rider==player and mount.transition.is_empty():start_horse_journey(mount)
 if active:
  age+=delta;swing_age+=delta
  var record: Dictionary=beats[beat_index];var t:=clampf(age/float(record.seconds),0,1)
  camera.global_position=camera_start.lerp(camera_end,smoothstep(0,1,t));camera.look_at(camera_target)
  if beat_index+1<beats.size() and record.place!=beats[beat_index+1].place and age>float(record.seconds)-.45:
   shade.color.a=smoothstep(float(record.seconds)-.45,float(record.seconds),age)
  update_acting(delta,t)
  if age>=float(record.seconds):
   beat_index+=1
   if beat_index>=beats.size():finish()
   else:enter_beat()
  return
 pose.apply("",0,delta)
 if state=="awaiting_inquiry" and inquiry.stage=="police" and not player.get_meta("opening_active",false):
  var local: Vector3=inquiry.station.to_local(player.global_position)
  if absf(local.x)<3 and local.z>18 and local.z<22 and absf(local.y-.9)<.6:start_inquiry()
 if state=="farm":
  if player.global_position.distance_to(community.farm.global_position)<7:
   if not player.get_meta("farm_lesson_started",false):player.set_meta("farm_lesson_started",true);show_lesson()
   else:check_practice(delta)
func _physics_process(delta: float) -> void:
 if not active or cue!="guards":return
 for i in entrance_paths.size():
  var guard: Node3D=inquiry.guards[i]
  var path: PackedVector3Array=entrance_paths[i]
  if path.is_empty():guard.travel_speed=0;face(guard,player.global_position);continue
  var offset:=path[0]-guard.global_position;offset.y=0
  if offset.length()<.09:path.remove_at(0);entrance_paths[i]=path;continue
  var step:=offset.normalized()*minf(offset.length(),delta*1.6)
  if not guard._patrol_body_blocked(step):guard.global_position+=step;guard.travel_speed=1.6
  else:guard.travel_speed=0
  guard.global_rotation.y=rotate_toward(guard.global_rotation.y,atan2(offset.x,offset.z),delta*5)
func update_acting(delta: float,t: float) -> void:
 impact_clock+=delta
 if cue=="beating":player.global_position=start_position+impact_direction*.045*exp(-impact_clock*8.0)
 if collar_cloth!=null:collar_cloth.apply(smoothstep(4.8,5.3,age) if cue=="collar" else 1.0 if cue=="guards" else 0.0)
 var record: Dictionary=beats[beat_index]
 var face_script=preload("res://story/dialogue_expression.gd")
 var speaking: float=face_script.speech_weight(age,float(record.seconds)) if not str(record.text).is_empty() else 0.0
 var hurt: bool=cue in ["beating","collapse","discard","throw","rescue","support_walk"]
 if hero_expression!=null:hero_expression.apply(.55 if cue in ["reception","optional","rescue"] else .20,0,.55 if cue in ["objection","collar","guards"] or hurt else 0,speaking if record.speaker=="Arjun" else 0,.8 if cue in ["discard","throw"] else face_script.blink_weight(age,.9))
 chacha.facial_expression.apply(.55 if cue in ["optional","rescue","drink","heal"] else 0,0,0,speaking if record.speaker=="Chacha" else 0,face_script.blink_weight(age,2.1))
 if police_expression!=null:police_expression.apply(0,.15,0,speaking if record.speaker=="Station officer" else 0,face_script.blink_weight(age,3.3))
 for index in inquiry.officials.size():
  var officer_speaking: bool=record.speaker==["District officer","First official","Second official"][index]
  var disdain: float=.35 if cue=="humiliation" and officer_speaking and record.speaker!="Arjun" else 0.0
  inquiry.expressions[index].apply(0,disdain,.3 if cue=="guards" and index==0 else 0,speaking if officer_speaking else 0,face_script.blink_weight(age,float(index)*1.3+.4))
 var action: String="collar" if cue in ["collar","guards"] else "down" if cue in ["collapse","discard","throw"] else "pain" if cue in ["beating","rescue","heal"] else "drink" if cue=="drink" else ""
 var amount:=1.0 if not action.is_empty() else 0.0
 if cue=="collar":amount=smoothstep(3.9,4.8,age)
 var progress:=-1.0
 if cue=="collapse":action="fall";progress=clampf(age/2.1,0,1)
 if cue=="support_walk":action="pain";amount=1

 if cue=="rescue":action="fall";amount=1;progress=1-smoothstep(.22,.92,t)
 if cue in ["bed_arrival","bed_sit","tea_offer","drink","heal"]:
  action="";amount=0;chacha.travel_speed=0;chacha._set_animation(&"idle",delta)
 if cue=="bed_sit":player.set_meta("rest_progress",lerpf(1.0,.38,smoothstep(0,1,t)))
 if cue in ["tea_offer","drink","heal"]:player.set_meta("rest_progress",.38)
 if cue in ["entry","chamber"]:
  move_hero_path(t,float(beats[beat_index].seconds))
  camera_target=player.global_position+Vector3.UP*.6
  if cue=="chamber" and t>.94:face(player,inquiry.officials[0].global_position)
 if cue in ["horse_departure","horse_arrival"]:
  journey_horse.global_position=start_position.lerp(finish_position,t);journey_horse.gait+=delta*3
  journey_horse._sync_rider()
  camera_target=journey_horse.global_position+Vector3.UP*1.3
 if cue=="horse_dismount" and journey_horse.get_meta("story_dismount_pending",false):
  if journey_horse.dismount():journey_horse.remove_meta("story_dismount_pending")
 pose.apply(action,amount,delta,progress)
 if progress>=0:visual.motion_tree.advance(0)
 if cue=="collar":
  var official: Node3D=inquiry.officials[0]
  var station: Node3D=inquiry.station
  var a:=station.to_global(Vector3(-7.4,0,-8.3));var b:=station.to_global(Vector3(-7.4,0,-5.3));var c:=station.to_global(Vector3(-7.8,0,-5.3))
  if age<.8:official.global_position=official_start.lerp(official_start+Vector3.UP*.48,smoothstep(0,.8,age));official.travel_speed=0
  elif age<2.2:official.global_position=(official_start+Vector3.UP*.48).lerp(a,(age-.8)/1.4);face(official,a+station.global_basis.x);official.travel_speed=1.5
  elif age<4.2:official.global_position=a.lerp(b,(age-2.2)/2);face(official,b+station.global_basis.z);official.travel_speed=1.5
  else:official.global_position=b.lerp(c,clampf((age-4.2)/.4,0,1));face(official,player.global_position);official.travel_speed=0
  player.global_position=start_position.lerp(finish_position,smoothstep(3.8,4.8,age))
 if cue in ["collar","guards"] and (cue=="guards" or age>=4.8):
  var official: Node3D=inquiry.officials[0]
  face(player,official.global_position)
  collar_contact_error=0
  for side in ["l","r"]:
   var chest: Vector3=official._skeleton.to_global(official._skeleton.get_bone_global_pose(official._bones["spine_02"]).origin)
   var target: Vector3=chest+official.global_basis*Vector3(.10 if side=="l" else -.10,.25,.18)
   collar_contact_error=maxf(collar_contact_error,solve_collar_palm(side,target,official))
  player.velocity=Vector3.ZERO
  if cue=="collar":
   var close: Vector3=inquiry.station.to_global(Vector3(-9.9,1.7,-5.1))
   camera.global_position=camera_start.lerp(close,smoothstep(4.6,5.4,age))
   camera.look_at((player.global_position+official.global_position)*.5+Vector3.UP*.75)
 if cue in ["reception","humiliation","objection","warning"]:
  player.velocity=Vector3.ZERO
  face(player,inquiry.police_prompt.get_meta("attendant").global_position if cue=="reception" else inquiry.officials[0].global_position)
 if cue=="beating":
  for guard in inquiry.guards:guard.cinematic_style=""
  var strike:=int(age/1.35)
  var phase:=fmod(age,1.35)/1.35
  var index:=strike%4
  var striking: Node3D=inquiry.guards[index]
  var target:=player.global_position+Vector3(0,.30 if index!=3 else .05,0)
  var near: Vector3=striking.global_position-player.global_position;near.y=0
  target+=near.normalized()*.28
  var contact: Vector3=striking.cinematic_attack(["rifle","punch","rifle","kick"][index],phase,target)
  strike_contact_error=contact.distance_to(target)
  if phase>=.48 and last_strike!=strike:
   last_strike=strike;visual.hit_phase=0;impact_clock=0
   impact_direction=(player.global_position-striking.global_position).normalized()
   WorldAudio.play_at("impact",target,-19)
 if cue=="discard":
  carry_contact_error=0
  player.global_position=start_position.lerp(finish_position,t)
  var rig: Skeleton3D=visual.skeleton
  var floor_y: float=start_position.y-1.5
  var shoulder_height: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["upperarm_l"]).origin)
  var hip_height: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["thigh_l"]).origin)
  player.global_position.y+=floor_y+.92-(shoulder_height.y+hip_height.y)*.5
  rig.force_update_all_bone_transforms()
  for i in 2:
   var guard: Node3D=inquiry.guards[i]
   var body_side: String="l" if i==0 else "r"
   var shoulder: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["upperarm_"+body_side]).origin)
   var hip: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["thigh_"+body_side]).origin)
   var support_midpoint: Vector3=shoulder.lerp(hip,.5)
   guard.global_position=Vector3(support_midpoint.x,player.global_position.y-1.75,support_midpoint.z)+inquiry.station.global_basis.x*(-.22 if i==0 else .22)
   guard.global_rotation.y=inquiry.station.global_rotation.y;guard.travel_speed=.5
   guard._set_animation(&"walk",0)
   guard.cinematic_carry=true;guard.pose_carry()
   for side in ["l","r"]:
    var bone: String=("upperarm_" if side=="r" else "thigh_")+("l" if i==0 else "r")
    guard.cinematic_palms[side]=rig.to_global(rig.get_bone_global_pose(visual.bones[bone]).origin)
    guard.solve_hand_contact(side,guard.cinematic_palms[side]);guard.set_grip(side,.6)
    carry_contact_error=maxf(carry_contact_error,guard.palm_world(side).distance_to(guard.cinematic_palms[side]))
 if cue=="throw":
  var flight:=clampf(age/1.0,0,1)
  player.global_position=start_position.lerp(finish_position,flight)+Vector3.UP*sin(flight*PI)*.28
 if cue=="support_walk":
  player.global_position=start_position.lerp(finish_position,t)
  player.velocity=inquiry.station.global_basis.z*.5
  chacha.global_position=player.global_position+inquiry.station.global_basis.x*.58-Vector3.UP*.9
  chacha.travel_speed=.5
 if cue in ["rescue","support_walk"]:
  var rig: Skeleton3D=visual.skeleton
  var shoulder_point: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["upperarm_l"]).origin)
  var elbow_point: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["lowerarm_l"]).origin)
  var bicep: Vector3=shoulder_point.lerp(elbow_point,.22)+player.get_node("VisualRoot").global_basis.x*.025
  bicep.y=maxf(bicep.y,player.global_position.y-.84)
  if cue=="rescue":
   # Kneel beside the actual shoulder, rather than beside the lying body's pelvis.
   chacha.global_position=Vector3(bicep.x,player.global_position.y-.9,bicep.z)+player.get_node("VisualRoot").global_basis.x*.42
   face(chacha,bicep)
  chacha._set_animation(&"walk" if cue=="support_walk" else &"idle",delta)
  var crouch: float=1.0-smoothstep(.45,.90,t) if cue=="rescue" else 0.0
  pose_support_crouch(crouch)
  chacha.solve_hand_contact("r",bicep);chacha.set_grip("r",.28)
  support_contact_error=chacha.palm_world("r").distance_to(bicep)
  if cue=="support_walk":
   var shoulder: Vector3=chacha._skeleton.to_global(chacha._skeleton.get_bone_global_pose(chacha._bones["upperarm_r"]).origin)+Vector3.UP*.06
   solve_palm("l",shoulder,.12)
 if cue=="bed_arrival":hold_helper_cup(0.0)
 if cue=="bed_sit":
  pose_support_crouch(.5*(1.0-smoothstep(.3,.9,t)))
  var rig: Skeleton3D=visual.skeleton
  var target: Vector3=rig.to_global(rig.get_bone_global_pose(visual.bones["upperarm_l"]).origin)+Vector3.DOWN*.10
  chacha.solve_hand_contact("r",target);chacha.set_grip("r",.25)
  support_contact_error=chacha.palm_world("r").distance_to(target)
  hold_helper_cup(.5*(1.0-smoothstep(.3,.9,t)))
 if cue in ["tea_offer","drink"]:
  cup.show()
  var rig: Skeleton3D=visual.skeleton
  var head: Transform3D=rig.get_bone_global_pose(visual.bones["head"])
  var mouth: Vector3=rig.to_global(head.origin)+player.get_node("VisualRoot").global_basis.z*.105-Vector3.UP*.025
  var resting: Vector3=player.global_position+player.get_node("VisualRoot").global_basis.z*.30+Vector3.UP*.16
  var target: Vector3=tea_start.lerp(resting,smoothstep(0,1,t)) if cue=="tea_offer" else resting.lerp(mouth-Vector3.UP*.055,smoothstep(.1,.4,t)*(1.0-smoothstep(.75,1,t)))
  var lift: float=smoothstep(.1,.4,t)*(1.0-smoothstep(.75,1,t)) if cue=="drink" else 0.0
  cup.global_transform=Transform3D(player.get_node("VisualRoot").global_basis*Basis(Vector3.RIGHT,-.18*lift),target)
  if cue=="drink" or t>.45:cup_contact_error=solve_cup_grip()
  if cue=="tea_offer" and t<.85:
   var receiving: Vector3=cup.to_global(Vector3(.045,0,0))
   chacha.solve_hand_contact("l",receiving);chacha.set_grip("l",.35)
   tea_helper_contact_error=chacha.palm_world("l").distance_to(receiving)
 elif cue not in ["bed_arrival","bed_sit"]:cup.hide()
 if cue=="demo":animate_demo(t)
func hold_helper_cup(crouch: float) -> void:
 cup.show()
 var grip: Vector3=chacha.to_global(Vector3(.22,1.0-.75*crouch,.25))
 chacha.solve_hand_contact("l",grip);chacha.set_grip("l",.4)
 cup.global_transform=Transform3D(player.get_node("VisualRoot").global_basis,chacha.palm_world("l")-player.get_node("VisualRoot").global_basis.x*.045)

func pose_support_crouch(amount: float) -> void:
 var rig: Skeleton3D=chacha._skeleton
 rig.set_bone_pose_position(chacha.foot_plant.pelvis,chacha.foot_plant.pelvis_position+chacha.foot_plant.pelvis_down*.73*amount)
 for pair in [["spine_02",.62],["thigh_l",-.9],["thigh_r",-.9],["calf_l",1.5],["calf_r",1.5]]:
  var bone: String=pair[0]
  rig.set_bone_pose_rotation(chacha._bones[bone],chacha._base_rotations[bone]*Quaternion(chacha._pitch_axes[bone],float(pair[1])*amount))
 rig.force_update_all_bone_transforms()
 if amount>.001:
  for side in ["l","r"]:
   var target: Vector3=rig.to_global(rig.get_bone_global_rest(chacha._bones["foot_"+side]).origin)
   chacha.foot_plant._solve(chacha.foot_plant.legs[side],rig.to_local(target))

func solve_collar_palm(side: String,target: Vector3,official: Node3D) -> float:
 var gear: Node3D=visual.equipment
 var rig: Skeleton3D=visual.skeleton
 var hand: int=visual.bones["hand_"+side]
 var parent: int=rig.get_bone_parent(hand)
 var inward: Vector3=official.global_basis.x*(-1.0 if side=="l" else 1.0)
 var forward: Vector3=official.global_basis.z.normalized()
 var across: Vector3=forward.cross(inward).normalized()
 var desired: Basis=rig.global_basis.inverse()*Basis(across,forward,inward)*(gear.palm_axes[side] as Basis).inverse()
 for iteration in 2:
  gear._solve_arm(side,rig.to_local(target)-desired*gear.palm_offsets[side])
  rig.set_bone_pose_rotation(hand,(rig.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
  rig.force_update_all_bone_transforms()
 var curl: float=lerpf(.12,.82,smoothstep(4.7,5.3,age)) if cue=="collar" else .82
 # Cloth grip is independent of the selected weapon's trigger-finger pose.
 for digit in ["index","middle","ring","pinky","thumb"]:
  for joint in ["01","02","03"]:
   var name: String=digit+"_"+joint+"_"+side
   rig.set_bone_pose_rotation(rig.find_bone(name),gear.rest_rotations[name])
 rig.force_update_all_bone_transforms()
 var palm: Basis=rig.get_bone_global_pose(hand).basis*gear.palm_axes[side]
 for digit in ["index","middle","ring","pinky"]:
  var pressure: float=.88 if digit=="index" else 1.0
  gear._rotate_digit(digit+"_01_"+side,palm.x,1.34*curl*pressure)
  gear._rotate_digit(digit+"_02_"+side,palm.x,1.08*curl*pressure)
  gear._rotate_digit(digit+"_03_"+side,palm.x,.64*curl)
 gear._rotate_digit("thumb_01_"+side,palm.y,(-.55 if side=="r" else .55)*curl)
 gear._rotate_digit("thumb_02_"+side,palm.x,.75*curl)
 gear._rotate_digit("thumb_03_"+side,palm.x,.45*curl)
 return rig.to_global(rig.get_bone_global_pose(hand)*gear.palm_offsets[side]).distance_to(target)

func solve_cup_grip() -> float:
 var gear: Node3D=visual.equipment
 var rig: Skeleton3D=visual.skeleton
 var target: Vector3=cup.to_global(Vector3(-.045,0,0))
 var inward:=cup.global_basis.x.normalized()
 var fingers:=cup.global_basis.y.normalized()
 var across:=fingers.cross(inward).normalized()
 var desired: Basis=rig.global_basis.inverse()*Basis(across,fingers,inward)*(gear.palm_axes["r"] as Basis).inverse()
 var hand: int=visual.bones["hand_r"];var parent: int=rig.get_bone_parent(hand)
 for iteration in 2:
  gear._solve_arm("r",rig.to_local(target)-desired*gear.palm_offsets["r"])
  rig.set_bone_pose_rotation(hand,(rig.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
  rig.force_update_all_bone_transforms()
 gear._grasp("r",.6)
 return rig.to_global(rig.get_bone_global_pose(hand)*gear.palm_offsets["r"]).distance_to(target)

func solve_palm(side: String,target: Vector3,curl: float) -> void:
 var gear: Node3D=visual.equipment;var rig: Skeleton3D=visual.skeleton
 var hand: int=visual.bones["hand_"+side]
 var basis:=rig.get_bone_global_pose(hand).basis
 gear._solve_arm(side,rig.to_local(target)-basis*gear.palm_offsets[side]);gear._grasp(side,curl)
func finish() -> void:
 var completed:=kind
 if hero_expression!=null:hero_expression.restore();hero_expression=null
 if police_expression!=null:police_expression.restore();police_expression=null
 if collar_cloth!=null:collar_cloth.restore();collar_cloth=null
 chacha.facial_expression.apply(0,0)
 release_story_horse()
 if player.get_meta("rest_action","")=="sleep":
  player.set_meta("rest_action","");player.set_meta("rest_progress",0.0);player.remove_meta("rest_waking")
  player.global_position=get_parent().get_node("ChachaHouse").to_global(Vector3(-3.0,1.1,1.5))
 active=false;caption.hide()
 for bar in bars:bar.hide()
 shade.color.a=0
 gameplay_camera.current=true
 player.set_meta("document_busy",prior_busy);player.set_meta("story_cinematic",false);player.set_physics_process(actor_physics);player.velocity=Vector3.ZERO
 visual.equipment.selected=gear_snapshot.get("selected",0);visual.equipment.stowed=gear_snapshot.get("stowed",true);visual.equipment._refresh()
 player.get_node("ChachaKit").active=gear_snapshot.get("spear",false)
 for i in hud.size():if is_instance_valid(hud[i]):hud[i].visible=hidden_hud[i]
 for official in inquiry.officials:official.speaking=false;official.attitude="neutral";official.attention=Vector3.ZERO;official.travel_speed=0
 for expression in inquiry.expressions:expression.apply(0,0)
 if demonstration_weapon!=null:demonstration_weapon.queue_free();demonstration_weapon=null
 chacha.global_transform=chacha_home;reset_actor_grounding(chacha);chacha.set_process(prior_chacha_process);chacha.state="settled"
 if completed=="optional":first_chacha_seen=true;get_parent().get_node("ChachaHouse").set_meta("advice_given",true)
 elif completed=="inquiry":
  for guard in inquiry.guards:guard.position=guard.get_meta("inquiry_post");guard.duty_state="guard";guard.travel_speed=0;guard.cinematic_style="";guard.cinematic_palms.clear();guard.cinematic_carry=false
  for official in inquiry.officials:official.transform=official.get_meta("inquiry_seat");official.seated=true
  state="farm";first_chacha_seen=true;inquiry.stage="released";inquiry.refresh_objective()
  get_parent().get_node("ChachaHouse").set_meta("advice_given",true)
 elif completed=="lesson":
  chacha.global_position=community.farm.to_global(Vector3(-5,0,2));chacha.state="training";chacha.set_process(false)
  for member in community.members:member.set_meta("training_hit","")
 refresh()
func _input(event: InputEvent) -> void:
 if not configured:return
 if active and event.is_action_pressed("jump"):
  # Finish at a safe checkpoint; a skip cannot bypass the interactive lessons.
  if kind=="inquiry":stage_action("heal")
  finish();get_viewport().set_input_as_handled()
 elif not active and state=="farm" and lesson==7 and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Q:
  if player.global_position.distance_to(community.farm.global_position)<12:
   player.get_node("RearGrapple").begin();get_viewport().set_input_as_handled()
func sync_training_clock() -> void:
 var clock = get_parent().get_node_or_null("GameTimeSystem")
 if clock!=null:
  clock.set_mission_clock_slowed(&"chacha_weapon_training",state=="farm" and lesson<LESSONS.size() and player.get_meta("farm_lesson_started",false))
func show_lesson() -> void:
 if lesson>=LESSONS.size():return
 sync_training_clock()
 var farm: Node3D=community.farm
 chacha.global_position=farm.to_global(Vector3(-5,0,2));chacha.state="training";chacha.route.clear()
 var explanation: String=["Hold the talwar ready, with room around you. Never swing at a friend without warning.","Let the blade reach your consenting partner. Keep your feet under you.","Jump, slash, then land balanced. I will show you; then you try.","Carry the spear upright. Keep its point away from your companions.","Thrust forward and recover the point. Your partner is ready.","Jump and thrust, then recover your stance.","Use the small blade at close range. Here we practise without injury.","Approach quietly from behind. Q holds and knocks down a consenting partner. Practise on all three."][lesson]
 start("lesson",[line("Chacha",explanation,6,Vector3(-2,1.8,5),Vector3(-5,1.2,2),"demo","farm")])
func setup_demo() -> void:
 chacha.global_position=community.farm.to_global(Vector3(-5,0,2));chacha.state="training"
 var path: String="res://environment/weapons/period_spear/period_spear.glb" if lesson in [3,4,5] else "res://environment/weapons/period_utility_knife/period_utility_knife.glb" if lesson==6 else "res://environment/weapons/Talwar/weapon_talwar_01.glb"
 if lesson!=7:demonstration_weapon=load(path).instantiate();add_child(demonstration_weapon)
 for id in ["talwar","spear","utility_knife"]:
  if not player.inventory.has_item(id):player.inventory.add_item(id,1)
func animate_demo(t: float) -> void:
 if demonstration_weapon==null:return
 var swing:=sin(t*TAU)*.30 if lesson not in [0,3] else .04*sin(t*TAU)
 var contact:=chacha.to_global(Vector3(-.25,1.0,.24+swing))
 chacha.solve_hand_contact("r",contact);chacha.set_grip("r",.45)
 var spear: bool=lesson in [3,4,5]
 var direction: Vector3=chacha.global_basis.y if spear and lesson==3 else (chacha.global_basis.z+Vector3.UP*sin(t*TAU)*.7).normalized() if spear else (chacha.global_basis.z+Vector3.UP*(sin(t*TAU)*1.2 if lesson!=0 else -.8)).normalized()
 var across: Vector3=chacha.global_basis.x
 var weapon_basis: Basis=Basis(across,direction,across.cross(direction)).orthonormalized() if spear else Basis(direction,Vector3.UP.cross(direction).normalized(),direction.cross(Vector3.UP.cross(direction).normalized())).orthonormalized()
 var grip: Vector3=Vector3(0,.8,0) if spear else Vector3(-.045,0,0) if lesson==6 else Vector3(-.095,-.002,0)
 demonstration_weapon.global_basis=weapon_basis
 demonstration_weapon.global_position=contact-weapon_basis*grip
 if lesson in [2,5]:chacha.global_position.y=community.farm.global_position.y+sin(t*PI)*.45
func practice_allowed(member: Node3D,hit: String) -> bool:
 if active or state!="farm" or player.global_position.distance_to(community.farm.global_position)>12:return false
 if member not in community.members:return false
 return (lesson==1 and hit=="sword" and member==community.members[0]) or (lesson==4 and hit=="spear" and member==community.members[1]) or (lesson==6 and hit=="knife" and member==community.members[2]) or (lesson==7 and hit=="takedown")
func check_practice(delta: float) -> void:
 if active:return
 var gear: Node3D=visual.equipment;var kit: Node=player.get_node("ChachaKit")
 var success:=false
 if lesson in [0,3]:
  var ready: bool=(gear.selected==0 and not gear.stowed and not kit.active) if lesson==0 else kit.active
  idle_age=idle_age+delta if ready and player.velocity.length()<.1 else 0
  success=idle_age>=2
 elif lesson in [1,4,6]:
  var index:=0 if lesson==1 else 1 if lesson==4 else 2
  success=community.members[index].get_meta("training_hit","")==LESSONS[lesson][1]
 elif lesson in [2,5]:
  success=not player.is_on_floor() and ((lesson==2 and player.get_node("TalwarSlash").elapsed<.5 and not gear.stowed and gear.selected==0) or (lesson==5 and kit.active and kit.thrust>=0))
 elif lesson==7:
  for i in 3:
   if community.members[i].get_meta("training_hit","")=="takedown" and i not in completed_partners:completed_partners.append(i)
  success=completed_partners.size()==3 and not player.get_node("RearGrapple").active
 if success:
  lesson+=1;idle_age=0
  if lesson>=LESSONS.size():state="complete";reset_partners();refresh()
  else:show_lesson()
func reset_partners() -> void:
 for member in community.members:
  member.set_meta("knocked_out",false);member.set_meta("training_hit","")
  member.get_node("Vitality").health=75;member.combat_react("rise")
func refresh() -> void:
 if not configured:return
 sync_training_clock()
 objective.visible=false
 if state=="farm":
  objective.text="Chacha · Meet me at the farm" if not player.get_meta("farm_lesson_started",false) else "Training · "+str(LESSONS[mini(lesson,LESSONS.size()-1)][0])
  inquiry.destination.global_position=community.farm.global_position
  inquiry.destination.set_meta("parking_label","Chacha · Farm practice")
 elif state=="complete":
  objective.text="Find Dev · Explore the refreshment courtyard and college for another lead."
  inquiry.destination.global_position=community.courtyard.global_position
  inquiry.destination.set_meta("parking_label","Find Dev · Refreshment courtyard")
 else:objective.text=""
func export_state() -> Dictionary:
 return {"state":state,"first_chacha_seen":first_chacha_seen,"lesson":lesson,"partners":completed_partners,"started":player.get_meta("farm_lesson_started",false)}
func restore_state(data: Dictionary) -> void:
 state=str(data.get("state","awaiting_inquiry"));first_chacha_seen=bool(data.get("first_chacha_seen",false));lesson=clampi(int(data.get("lesson",0)),0,LESSONS.size())
 completed_partners.assign(data.get("partners",[]));player.set_meta("farm_lesson_started",bool(data.get("started",false)))
 if state=="farm" and player.get_meta("farm_lesson_started",false):
  chacha.global_position=community.farm.to_global(Vector3(-5,0,2));chacha.state="training";chacha.set_process(false)
  for i in completed_partners:
   if i>=0 and i<community.members.size():community.members[i].set_meta("training_hit","takedown");community.members[i].set_meta("knocked_out",true);community.members[i].combat_react("down")
 if state not in ["awaiting_inquiry","farm","complete"]:state="awaiting_inquiry"
 refresh()
func _exit_tree() -> void:
 var clock = get_parent().get_node_or_null("GameTimeSystem")
 if is_instance_valid(clock):clock.set_mission_clock_slowed(&"chacha_weapon_training",false)
 if hero_expression!=null:hero_expression.restore()
 if police_expression!=null:police_expression.restore()
 if collar_cloth!=null:collar_cloth.restore()
 if is_instance_valid(player) and active:
  player.set_meta("document_busy",prior_busy);player.set_meta("story_cinematic",false);player.set_physics_process(actor_physics)

func set_hero_path(goal: Vector3) -> void:
 path_origin=player.global_position
 var local_origin: Vector3=inquiry.station.to_local(path_origin)
 if cue=="entry" and local_origin.z>20:
  # Station navigation starts inside the gate; retain the visible outside approach.
  var gate: Vector3=inquiry.station.to_global(Vector3(0,inquiry.station.to_local(goal).y,19.2))
  hero_path=inquiry.coordinator.path(gate,goal,.29)
  if not hero_path.is_empty():hero_path.insert(0,gate)
 else:
  hero_path=inquiry.coordinator.path(path_origin,goal,.29)
 for i in hero_path.size():hero_path[i].y=goal.y
 if hero_path.is_empty():push_error("Story approach path is blocked")
func move_hero_path(t: float,seconds: float) -> void:
 if hero_path.is_empty():return
 var total:=0.0;var previous:=path_origin
 for point in hero_path:total+=previous.distance_to(point);previous=point
 var remaining:=total*t;previous=path_origin
 for point in hero_path:
  var distance:=previous.distance_to(point)
  if remaining<=distance and distance>.001:
   player.global_position=previous.lerp(point,remaining/distance);face(player,point)
   player.velocity=(point-previous).normalized()*total/seconds;return
  remaining-=distance;previous=point
 player.global_position=hero_path[-1];player.velocity=Vector3.ZERO
func release_story_horse() -> void:
 if not is_instance_valid(journey_horse):return
 journey_horse.pace=0;journey_horse.velocity=Vector3.ZERO
 if journey_horse.rider==player:
  journey_horse.rider=null;journey_horse.transition=""
  player.set_meta("mounted_vehicle",null);player.set_meta("horse_transition","")
  player.collision_layer=journey_horse.saved_layer;player.collision_mask=journey_horse.saved_mask
 journey_horse.remove_meta("story_dismount_pending");journey_horse.set_physics_process(horse_physics)
 journey_horse=null
