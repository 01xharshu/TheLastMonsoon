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
var cup: MeshInstance3D
var demonstration_weapon: Node3D
var configured:=false
var entrance_paths: Array[PackedVector3Array]=[]
var hero_expression: RefCounted
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
 configured=true;refresh()
func line(speaker: String,text: String,seconds: float,at: Vector3,target: Vector3,action:="",place:="station") -> Dictionary:
 return {"speaker":speaker,"text":text,"seconds":seconds,"at":at,"target":target,"cue":action,"place":place}
func begin_optional() -> bool:
 if not configured or active or first_chacha_seen or player.get_meta("document_busy",false):return false
 var list: Array[Dictionary]=[]
 for record in preload("res://world/suryagarh/settlements/chacha_advice.gd").LINES:
  list.append(line(record.speaker,record.text,record.seconds,Vector3(2,1.7,6),Vector3(-.85,1.3,3.3),"optional","house"))
 start("optional",list);return true
func start_inquiry(_id:="police") -> bool:
 if not configured or active or state!="awaiting_inquiry" or player.health<=0:return false
 if player.get_meta("document_busy",false) or get_tree().root.get_node("SaveManager").police_case_active(player):return false
 var list: Array[Dictionary]=[]
 list.append(line("","",2,Vector3(7,2.1,23),Vector3(0,1,18),"entry"))
 for record in inquiry.POLICE_LINES:
  list.append(line(record[0],record[1],record[2],Vector3(6,1.65,9.5),Vector3(8.6,1.3,7.4),"reception"))
 list.append(line("","",2.5,Vector3(-6.5,1.7,-3.2),Vector3(-9.5,1.2,-8),"chamber"))
 for i in inquiry.OFFICE_LINES.size():
  var record: Array=inquiry.OFFICE_LINES[i]
  list.append(line(record[0],record[1],record[2],Vector3(-8,1.7,-4),Vector3(-9.5,1.4,-8),"humiliation" if i<5 else "objection" if i==5 else "collar"))
 list.append(line("District officer","Guards! Get him off me!",8,Vector3(-10.5,1.8,-4),Vector3(-5.5,1.15,-7),"guards"))
 list.append(line("Guard","Down!",7,Vector3(-10.5,1.6,-3.5),Vector3(-7.8,1.05,-4.6),"beating"))
 list.append(line("","",4,Vector3(-9.8,1.2,-3.2),Vector3(-7.8,.4,-4.6),"collapse"))
 list.append(line("Guard","Throw him outside. Let everyone see what comes of his insolence.",4,Vector3(4,1.4,27),Vector3(0,.35,25),"discard"))
 list.append(line("Arjun","Dev...",5,Vector3(2,1.15,26),Vector3(0,.6,25),"rise"))
 list.append(line("","",5,Vector3(3,1.6,27),Vector3(0,1,27),"stumble"))
 list.append(line("Chacha","Arjun! What have they done to you? Come with me.",6,Vector3(2,1.6,29),Vector3(0,1.3,27),"rescue"))
 list.append(line("Chacha","Slowly. Drink this. Your body needs rest.",6,Vector3(1.5,1.65,3.8),Vector3(-.8,1.2,2),"drink","house"))
 list.append(line("Chacha","Bare hands against armed men will only get you hurt. First heal. Then meet me at the farm. I will teach you.",8,Vector3(1.5,1.65,3.8),Vector3(-.8,1.3,2),"heal","house"))
 inquiry.stage="cinematic";inquiry.refresh_objective();start("inquiry",list);return true
func start(which: String,list: Array[Dictionary]) -> void:
 active=true;kind=which;beats=list;beat_index=0;age=0;cue=""
 if which in ["inquiry","optional"]:
  hero_expression=preload("res://story/dialogue_expression.gd").new();hero_expression.configure(visual)
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
 var place: Node3D=inquiry.station if record.place=="station" else get_parent().get_node("ChachaHouse") if record.place=="house" else community.farm
 camera_start=place.to_global(record.at);camera_end=camera_start+place.global_basis.x*.22
 camera_target=place.to_global(record.target)
 if cue=="optional":
  camera_target=(player.global_position+chacha.global_position)*.5+Vector3.UP*.65
  camera_start=camera_target+chacha.global_basis.x*2.2+chacha.global_basis.z*2.5+Vector3.UP*.35
  camera_end=camera_start+chacha.global_basis.x*.22
 if cue!=previous:
  shade.color.a=1;create_tween().tween_property(shade,"color:a",0,.65)
  stage_action(cue)
 camera.global_position=camera_start;camera.look_at(camera_target)
 for i in inquiry.officials.size():
  inquiry.officials[i].speaking=record.speaker==["District officer","First official","Second official"][i]
  inquiry.officials[i].attitude="mocking" if cue=="humiliation" else "neutral"
  inquiry.expressions[i].apply(0,1 if cue=="humiliation" else 0)
func stage_action(action: String) -> void:
 var station: Node3D=inquiry.station
 if action=="entry":player.global_position=station.to_global(Vector3(0,.9,19))
 elif action=="reception":player.global_position=station.to_global(Vector3(8.3,.9,9));face(player,station.to_global(Vector3(9,1,6.8)))
 elif action=="chamber":player.global_position=station.to_global(Vector3(-9.5,.9,-5.2));face(player,inquiry.officials[0].global_position)
 elif action=="collar":
  inquiry.officials[0].global_position=station.to_global(Vector3(-7.8,0,-5.3));inquiry.officials[0].rotation.y=0
  start_position=player.global_position;finish_position=station.to_global(Vector3(-7.8,.9,-4.6));face(player,inquiry.officials[0].global_position)
 elif action=="guards":
  entrance_paths.clear()
  for i in 4:
   var guard: Node3D=inquiry.guards[i]
   guard.global_position=station.to_global(Vector3(-3,0,[-4.2,-5.8,-8.8,-10.4][i]))
   var goal:=station.to_global(Vector3(-7.8+[-.85,.85,-.6,.6][i],0,-4.6+[.4,.4,-.5,-.5][i]))
   entrance_paths.append(inquiry.coordinator.path(guard.global_position,goal,.29))
   guard.duty_state="restraint";guard.travel_speed=0
  swing_age=0
 elif action=="beating":
  for i in 4:
   inquiry.guards[i].global_position=station.to_global(Vector3(-7.8+[-.85,.85,-.6,.6][i],0,-4.6+[.4,.4,-.5,-.5][i]))
   face(inquiry.guards[i],player.global_position);inquiry.guards[i].travel_speed=0
  swing_age=0
 elif action=="collapse":player.health=maxf(20,minf(player.health,25))
 elif action=="discard":
  player.global_position=station.to_global(Vector3(0,.9,25));face(player,station.to_global(Vector3(0,1,29)))
  for guard in inquiry.guards:guard.position=guard.get_meta("inquiry_post");guard.duty_state="guard";guard.travel_speed=0
 elif action=="stumble":start_position=player.global_position;finish_position=start_position+station.global_basis.z*2
 elif action=="rescue":chacha.global_position=player.global_position+Vector3(0,-.9,1);face(chacha,player.global_position)
 elif action in ["drink","heal"]:
  player.global_position=get_parent().get_node("ChachaHouse").to_global(Vector3(-.8,1.1,2));face(player,get_parent().get_node("ChachaHouse").to_global(Vector3(.2,1,2)))
  chacha.global_position=player.global_position+Vector3(.9,-.9,0);face(chacha,player.global_position)
  if action=="heal":player.health=player.MAX_HEALTH
 elif action=="demo":setup_demo()
func face(actor: Node3D,target: Vector3) -> void:
 var offset:=target-actor.global_position
 if actor==player:player.get_node("VisualRoot").global_rotation.y=atan2(offset.x,offset.z)
 else:actor.global_rotation.y=atan2(offset.x,offset.z)
func _process(delta: float) -> void:
 if not configured:return
 if active:
  age+=delta;swing_age+=delta
  var record: Dictionary=beats[beat_index];var t:=clampf(age/float(record.seconds),0,1)
  camera.global_position=camera_start.lerp(camera_end,smoothstep(0,1,t));camera.look_at(camera_target)
  if age>float(record.seconds)-.45:shade.color.a=smoothstep(float(record.seconds)-.45,float(record.seconds),age)
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
 if hero_expression!=null:hero_expression.apply(.6 if cue in ["reception","optional","rescue"] else .25,0,.8 if cue in ["objection","collar","guards"] else 0)
 chacha.facial_expression.apply(.65 if cue in ["optional","rescue","drink","heal"] else 0,0)
 var action: String="collar" if cue in ["collar","guards"] else "down" if cue in ["collapse","discard"] else "pain" if cue in ["beating","stumble","rescue","heal"] else "drink" if cue=="drink" else ""
 var amount:=1.0 if not action.is_empty() else 0.0
 if cue=="rise":action="down";amount=1-smoothstep(.15,.9,t)
 pose.apply(action,amount,delta)
 if cue=="collar":player.global_position=start_position.lerp(finish_position,smoothstep(0,1,clampf(age/1.2,0,1)))
 if cue in ["collar","guards"] and (cue=="guards" or age>=1.0):
  var official: Node3D=inquiry.officials[0]
  for side in ["l","r"]:
   var target:=official.to_global(Vector3(.10 if side=="l" else -.10,1.45,.11))
   solve_palm(side,target,.65)
  if swing_age>.8:official.combat_react("held");swing_age=0
 if cue=="humiliation":
  for official in inquiry.officials:
   official.attitude="mocking"
   var head: int=official._bones.get("head",-1)
   if head>=0:official._skeleton.set_bone_pose_rotation(head,official._base_rotations.head*Quaternion(official._pitch_axes.head,sin(age*7)*.06))
 if cue=="beating" and swing_age>.55:
  swing_age=0;var guard: Node3D=inquiry.guards[int(age/.55)%4];guard.combat_react("strike")
  visual.hit_phase=0;WorldAudio.play_at("impact",player.global_position,-19)
 if cue=="beating":
  var striking: Node3D=inquiry.guards[int(age/.55)%4]
  var phase:=fmod(age,.55)/.55
  if phase>.32 and phase<.65:striking.solve_hand_contact("r",player.global_position+Vector3(0,.30,0));striking.set_grip("r",.7)
 if cue=="stumble":
  player.global_position=start_position.lerp(finish_position,t);player.velocity=inquiry.station.global_basis.z*.4
 if cue=="drink":
  cup.show();var target: Vector3=player.global_position+Vector3(0,.56,0)+player.get_node("VisualRoot").global_basis.z*.13
  cup.global_position=target;solve_palm("r",target,.45)
 else:cup.hide()
 if cue=="demo":animate_demo(t)
func solve_palm(side: String,target: Vector3,curl: float) -> void:
 var gear: Node3D=visual.equipment;var rig: Skeleton3D=visual.skeleton
 var hand: int=visual.bones["hand_"+side]
 var basis:=rig.get_bone_global_pose(hand).basis
 gear._solve_arm(side,rig.to_local(target)-basis*gear.palm_offsets[side]);gear._grasp(side,curl)
func finish() -> void:
 var completed:=kind
 if hero_expression!=null:hero_expression.restore();hero_expression=null
 chacha.facial_expression.apply(0,0)
 active=false;caption.hide()
 for bar in bars:bar.hide()
 shade.color.a=1;create_tween().tween_property(shade,"color:a",0,.65)
 gameplay_camera.current=true
 player.set_meta("document_busy",prior_busy);player.set_meta("story_cinematic",false);player.set_physics_process(actor_physics);player.velocity=Vector3.ZERO
 visual.equipment.selected=gear_snapshot.get("selected",0);visual.equipment.stowed=gear_snapshot.get("stowed",true);visual.equipment._refresh()
 player.get_node("ChachaKit").active=gear_snapshot.get("spear",false)
 for i in hud.size():if is_instance_valid(hud[i]):hud[i].visible=hidden_hud[i]
 for official in inquiry.officials:official.speaking=false;official.attitude="neutral"
 for expression in inquiry.expressions:expression.apply(0,0)
 if demonstration_weapon!=null:demonstration_weapon.queue_free();demonstration_weapon=null
 chacha.global_transform=chacha_home;chacha.set_process(prior_chacha_process);chacha.state="settled"
 if completed=="optional":first_chacha_seen=true;get_parent().get_node("ChachaHouse").set_meta("advice_given",true)
 elif completed=="inquiry":
  for guard in inquiry.guards:guard.position=guard.get_meta("inquiry_post");guard.duty_state="guard";guard.travel_speed=0
  for i in 3:inquiry.officials[i].position=Vector3([-9.5,-11.4,-7.7][i],0,-8.3)
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
func show_lesson() -> void:
 if lesson>=LESSONS.size():return
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
 objective.visible=not active
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
 if hero_expression!=null:hero_expression.restore()
 if is_instance_valid(player) and active:
  player.set_meta("document_busy",prior_busy);player.set_meta("story_cinematic",false);player.set_physics_process(actor_physics)
