extends Node3D
## Saved continuation after Chacha's final lesson. No completion by proximity alone.
const Startup=preload("res://systems/world_startup.gd")
const Sites=preload("res://story/rebellion_sites.gd")
const Sight=preload("res://systems/visual_perception.gd")
const Actions=preload("res://systems/action_permissions.gd")
const Budget=preload("res://systems/simulation_budget.gd")
const STAGES=["dormant","ambush","confront","escape","follow","briefing","inspect","load","shoot","raid_ready","infiltrate","collect","rope","return","complete"]
const GATE_FOLLOW_ROUTE=[Vector2(11.5,81),Vector2(0,80),Vector2(0,73),Vector2(-43,73),Vector2(-43,82.5),Vector2(-56,83)]
const HIDEOUT_FOLLOW_ROUTE=[Vector3(0,3.8,24),Vector3(0,3.8,18),Vector3(0,.2,7),Vector3(0,.2,2),Vector3(-3,.2,2)]
var world: Node3D
var player: CharacterBody3D
var encounters: Node
var rifle: Node
var grapple: Node
var hero: Node3D
var story_map: Control
var clock: Node
var inquiry: Node
var predecessor: Node
var sites: Node3D
var action_service: Node
var cinematic_lease=-1
var pending_restore: Dictionary={}
var restore_waiting=false
var configured=false
var startup_task=-1
var stage="dormant"
var active=false
var cinematic=""
var dialogue_voice: AudioStreamPlayer
var voiced_caption := ""
var voiced_slot := 0.0
var age=0.0
var suspicion=0.0
var disguise=false
var disguise_guard=0
var stripped_guards: Array[int]=[]
var captured_rifles=0
var outfit=preload("res://story/rebellion_disguise.gd").new()
var collected: Array[int]=[]
var target_hits=0
var range_transferred:=false
var range_lease:=-1
var reload_seen=false
var starting_shots=0
var officer_age=0.0
var guard_age=0.0
var simulation_elapsed=0.0
var follow_index=0
var checkpoint=Vector3.ZERO
var jump_origin=Vector3.ZERO
var rope_origin=Vector3.ZERO
var rope_contact_error=INF
var camera: Camera3D
var shade: ColorRect
var title_card: Label
var caption: Label
var bars: Array[ColorRect]=[]
var gameplay_camera: Camera3D
var prior_physics=true
var prior_busy=false
var hidden_ui: Array[Node]=[]
var prior_visibility: Array[bool]=[]
var map_waypoint=Vector2.INF
var outcome=""
var fight_age=0.0
var fight_hit=false
func _ready() -> void:
 name="RebellionStory";process_priority=100;startup_task=Startup.begin("Rebellion mission");call_deferred("configure")
func configure() -> void:
 world=get_parent();player=world.get_node("Player");inquiry=world.get_node("DevInquiry");predecessor=world.get_node("DevStory")
 if not inquiry.configured or not predecessor.configured:call_deferred("configure");return
 encounters=world.get_node("CombatEncounters");rifle=player.get_node("RifleCombat");grapple=player.get_node("RearGrapple");hero=player.get_node("VisualRoot/CharacterVisual");story_map=player.get_node("UI/WorldMap");clock=world.get_node("GameTimeSystem")
 action_service=Actions.install(player)
 sites=Sites.new();sites.name="RebellionSites";add_child(sites);await sites.configure(self)
 sites.officer.get_node("Vitality").died.connect(officer_defeated)
 gameplay_camera=player.get_node("CameraPivot/SpringArm3D/Camera3D")
 dialogue_voice=AudioStreamPlayer.new();dialogue_voice.name="DialogueVoice";add_child(dialogue_voice)
 camera=Camera3D.new();camera.name="RebellionCamera";camera.fov=52;add_child(camera)
 var layer=CanvasLayer.new();layer.layer=85;add_child(layer)
 shade=ColorRect.new();shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0)
 title_card=Label.new();layer.add_child(title_card);title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER);title_card.offset_left=-500;title_card.offset_right=500;title_card.offset_top=-45;title_card.offset_bottom=45;title_card.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title_card.add_theme_font_size_override("font_size",32);title_card.add_theme_color_override("font_color",Color(.9,.8,.5));title_card.hide()
 caption=Label.new();caption.z_index=1;title_card.z_index=1;layer.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_left=70;caption.offset_right=-70;caption.offset_top=-110;caption.offset_bottom=-24;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_theme_font_size_override("font_size",23);caption.add_theme_constant_override("outline_size",5);caption.hide()
 for top in [true,false]:
  var bar=ColorRect.new();layer.add_child(bar);bar.color=Color.BLACK;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
  if top:bar.offset_bottom=65
  else:bar.offset_top=-120
  bars.append(bar);bar.hide()
 configured=true
 if restore_waiting:
  var saved=pending_restore;pending_restore={};restore_waiting=false
  restore_state(saved)
 Startup.finish(startup_task)
func ground(at: Vector3) -> Vector3:
 return Vector3(at.x,world.layout.height(at.x,at.z)+.06,at.z)
func near(at: Vector3,radius: float) -> bool:
 return player.global_position.distance_to(at)<radius
func objective() -> String:
 if rear_target()!=null:return "Q · Silent rear takedown"
 match stage:
  "ambush":return "A few days later · Hide behind the tree by the superior’s office."
  "confront":return "The superior is walking to his carriage. Confront him."
  "escape":return "Crime witnessed · Escape toward the ruined fort. Take the superior’s horse or fight your way out."
  "follow":return "Follow Mangal Pandey into the fort hideout."
  "briefing":return "Speak to Mangal Pandey in the hideout."
  "inspect":return "Mangal: Take an Enfield from the rifle rack."
  "load":return equip_rifle_instruction()
  "shoot":return rifle_instruction()
  "raid_ready":return "Speak to Mangal to begin the weapons raid with two companions."
  "infiltrate":return "Enter the magazine unseen. Use the left stairs to the second-floor weapons room. Q behind a sentry; E to take his uniform."
  "collect":return "Collect all four rifle bundles · %d/4. Stay out of the patrols’ sight."%collected.size()
  "rope":return "Reach the rear window and rig the rope to the boundary wall."
  "return":return "Drive the loaded goods cart to the hideout. Stop inside the rectangular parking marker."
  "complete":return "Weapons delivered · Mangal’s fighters now have twelve captured rifles."
 return ""
func destination() -> Dictionary:
 if not configured or stage=="dormant" or active:return {}
 var at=sites.tree.global_position-Vector3(0,0,1.5)
 match stage:
  "confront":at=sites.officer.global_position
  "escape":at=ground(sites.fort.to_global(Vector3(0,0,105)))
  "follow":at=sites.mangal.global_position
  "briefing","raid_ready":at=sites.prompts.briefing.global_position
  "inspect":at=sites.prompts.weapons.global_position
  "load":at=sites.prompts.weapons.global_position
  "shoot":at=sites.firing_line.global_position
  "infiltrate":at=sites.raid.to_global(Vector3(-5,3.7,-3))
  "collect":
   for i in sites.bundles.size():
    if i not in collected:at=sites.bundles[i].global_position;break
  "rope":at=sites.prompts.rope.global_position
  "return":at=sites.return_bay.global_position
  "complete":return {}
 return {"position":at+Vector3.UP,"label":objective(),"endpoint":""}
func set_stage(next: String) -> void:
 if next!="shoot" and range_lease>=0:release_range()
 stage=next;age=0
 if is_instance_valid(sites.rack_rifle):sites.rack_rifle.visible=stage in ["dormant","ambush","confront","escape","follow","briefing","inspect"]
 clock.set_mission_daylight_locked(&"mangal_weapon_training",stage not in ["dormant","raid_ready","complete"])
 if stage=="complete":
  inquiry.destination.set_meta("parking_label","")
  if story_map.waypoint.is_equal_approx(map_waypoint):story_map.waypoint=Vector2.INF;story_map.selected_site=""
 var point=destination()
 if not point.is_empty():
  var at: Vector3=point.position;map_waypoint=Vector2(at.x,at.z)
  inquiry.destination.global_position=at;inquiry.destination.set_meta("parking_label",objective())
  story_map.follow_story_destination()
func _process(delta: float) -> void:
 if not configured or get_tree().paused:return
 if active:update_cinematic(delta);return
 if stage=="dormant":
  if predecessor.state=="complete" and not predecessor.active:begin_cinematic("days")
  return
 if player.health<=0 or player.get_meta("detention_action","")!="":return
 update_target_hits()
 age+=delta
 match stage:
  "ambush":
   if near(sites.tree.global_position-Vector3(0,0,1.5),2):set_stage("confront");officer_age=0
  "confront":
   officer_age+=delta
   if near(sites.officer.global_position,2.5):
    fight_age+=delta
    if fight_age>=1.5:sites.officer.combat_react("strike");fight_age=0;fight_hit=false
    if fight_age>.3 and not fight_hit and near(sites.officer.global_position,1.7):player.receive_combat_hit(8,sites.officer);fight_hit=true
    var offset: Vector3=player.global_position-sites.officer.global_position;sites.officer.rotation.y=atan2(offset.x,offset.z)
   else:move_actor(sites.officer,sites.parking.to_global(Vector3(1,0,-4)),delta,1.15)
  "escape":
   if near(ground(sites.fort.to_global(Vector3(0,0,105))),25):
    var mount=(player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)
    if mount==sites.horse and sites.horse.transition.is_empty():begin_cinematic("rescue")
    elif mount==null:player.inventory.message_requested.emit("Mangal: Take the horse. I will draw alongside you.")
  "follow":advance_follow(delta)
  "load":
   if hero.equipment.selected==1 and not hero.equipment.stowed and not player.inventory_ui.is_open() and not player.get_meta("weapon_wheel_open",false) and not player.get_meta("map_open",false):
    begin_cinematic("range_entry")
  "shoot":
   if target_hits>=1:
    set_stage("raid_ready")
   else:
    caption.text=rifle_instruction()
    if rifle.rounds==0 and rifle.reload_remaining<=0:
     if player.inventory.get_item_count("paper_cartridges")==0:player.inventory.add_item("paper_cartridges",1)
     rifle.start_reload()
  "infiltrate","collect":
   update_raid(delta)
   if stage=="infiltrate" and near(sites.raid.to_global(Vector3(-2,4.6,-4)),6) and player.global_position.y>sites.raid.global_position.y+3:set_stage("collect")
  "return":
   sites.return_bay.visible=player.global_position.distance_to(sites.return_bay.global_position)<45
   sites.parking_material.albedo_color.a=move_toward(sites.parking_material.albedo_color.a,1,delta*2)
   var local: Vector3=sites.return_bay.to_local(sites.goods.global_position)
   if sites.goods.rider==player and cart_in_delivery_bay() and absf(sites.goods.boarding.speed)<.35:
    begin_cinematic("delivery")
func input_label(action:String,fallback:String) -> String:
 for event in InputMap.action_get_events(action):
  if event is InputEventMouseButton:
   if event.button_index==MOUSE_BUTTON_RIGHT:return "Right click"
   if event.button_index==MOUSE_BUTTON_LEFT:return "Left click"
  if event is InputEventJoypadMotion:
   if event.axis==JOY_AXIS_TRIGGER_LEFT:return "Left trigger"
   if event.axis==JOY_AXIS_TRIGGER_RIGHT:return "Right trigger"
  if event is InputEventKey:return OS.get_keycode_string(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
  if event is InputEventJoypadButton:
   match event.button_index:
    JOY_BUTTON_RIGHT_SHOULDER:return "Right bumper"
    JOY_BUTTON_DPAD_UP:return "D-pad up"
    _:return event.as_text().get_slice(" (",0)
 return fallback

func equip_rifle_instruction() -> String:
 if SaveManager.active_input_device=="controller":
  if hero.equipment.selected==1:return input_label("stow_weapon","D-pad up")+" · Draw the Enfield"
  return input_label("next_weapon","Right bumper")+" · Equip the Enfield"
 return "Press 2 to equip the Enfield"

func rifle_instruction() -> String:
 if rifle.reload_remaining>0 or rifle.rounds==0:return "Preparing another cartridge…"
 var aim_label:=input_label("aim","Right click")
 var fire_label:=input_label("attack","Left click")
 return "Keep aiming · "+fire_label+" to fire at the circle" if rifle.aiming else "Hold "+aim_label+" to aim · "+fire_label+" to fire"

func place_at_firing_line() -> void:
 player.global_position=sites.firing_line.global_position+Vector3.UP*.96
 player.velocity=Vector3.ZERO
 var toward:Vector3=sites.target.global_position-player.global_position
 var eye_height:float=player.get_node("StealthStance").camera_height()
 player.camera_pitch=atan2(toward.y-eye_height,Vector2(toward.x,toward.z).length())
 player.camera_pivot.global_rotation=Vector3(player.camera_pitch,atan2(-toward.x,-toward.z),0)
 gameplay_camera.rotation=Vector3.ZERO
 player.visual_root.global_rotation.y=atan2(toward.x,toward.z)

func enter_range() -> void:
 if range_lease<0:
  var domains:Array[StringName]=[&"move",&"interact",&"board"]
  range_lease=action_service.acquire(self,domains)
 if range_lease<0:
  set_stage("load")
  return
 player.set_meta("rifle_lesson",true)
 hero.equipment.select_weapon(1)
 rifle.cancel_reload()
 rifle.rounds=1
 rifle.loaded=true
 starting_shots=rifle.shots_fired
 for impact in rifle.impacts:
  if is_instance_valid(impact):impact.set_meta("lesson_counted",true)
 target_hits=0
 set_stage("shoot")
 caption.text=rifle_instruction()
 caption.show()

func release_range() -> void:
 action_service.release(range_lease)
 range_lease=-1
 if is_instance_valid(player):player.remove_meta("rifle_lesson")
 if is_instance_valid(caption):caption.hide()

func update_target_hits() -> void:
 if stage!="shoot":return
 var gun: Node=rifle
 if gun.shots_fired<=starting_shots:return
 starting_shots=gun.shots_fired
 for impact in gun.impacts:
  if is_instance_valid(impact) and impact.get_parent()==sites.target and not impact.get_meta("lesson_counted",false):
   impact.set_meta("lesson_counted",true);target_hits+=1
func reset_grounding(actor: Node3D) -> void:
 actor.foot_plant.clear();actor.foot_plant.reset_pose()
 for side in ["l","r"]:
  var foot: int=actor._bones["foot_"+side]
  actor.foot_plant.ankle_height[side]=actor._skeleton.to_global(actor._skeleton.get_bone_global_rest(foot).origin).y
func move_actor(actor: Node3D,goal: Vector3,delta: float,speed: float,ground_step:=false) -> bool:
 var offset=goal-actor.global_position
 if ground_step:offset.y=0
 if offset.length()<.2:actor.travel_speed=0;return true
 var step=offset.normalized()*minf(speed*delta,offset.length())
 if ground_step:step=ground(actor.global_position+step)-actor.global_position
 var query=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.9,actor.global_position+step+Vector3.UP*.9,1);query.exclude=[actor.body_collider.get_rid(),actor.get_node("Vitality").hit_body.get_rid()]
 if not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():actor.travel_speed=0;return false
 actor.global_position+=step;actor.rotation.y=atan2(offset.x,offset.z);actor.travel_speed=speed;return false
func uses_fort_gate() -> bool:
 return sites.fort.get("embedded_in_world")==true

func follow_route_size() -> int:
 return HIDEOUT_FOLLOW_ROUTE.size()+(GATE_FOLLOW_ROUTE.size() if uses_fort_gate() else 0)

func follow_destination(index:int) -> Vector3:
 if uses_fort_gate():
  if index<GATE_FOLLOW_ROUTE.size():
   var point:Vector2=GATE_FOLLOW_ROUTE[index]
   return ground(sites.fort.to_global(Vector3(point.x,0,point.y)))
  index-=GATE_FOLLOW_ROUTE.size()
 return sites.cellar.to_global(HIDEOUT_FOLLOW_ROUTE[index])

func advance_follow(delta: float) -> void:
 if not near(sites.mangal.global_position,9):sites.mangal.travel_speed=0;return
 if move_actor(sites.mangal,follow_destination(follow_index),delta,1.4,uses_fort_gate() and follow_index<GATE_FOLLOW_ROUTE.size()):
  follow_index+=1
  if follow_index==follow_route_size():set_stage("briefing")
func officer_defeated() -> void:
 if stage not in ["ambush","confront"]:return
 var police: Node=encounters
 # The office witness reports a visible killing; use the existing stars and pursuit.
 var witnesses: Array[String]=["superior_office_witness"]
 police.record_incident("murder",sites.officer.global_position,witnesses,10)
 set_stage("escape")
func can_request(id: String) -> bool:
 if not configured or active or player.health<=0:return false
 if id.begins_with("uniform"):
  var index:=int(id.trim_prefix("uniform"))
  return stage in ["infiltrate","collect"] and not disguise and index>=0 and index<sites.guards.size() and (sites.guards[index].get_meta("dead",false) or sites.guards[index].get_meta("knocked_out",false))
 if id=="briefing":return stage=="briefing"
 if id=="weapons":return stage=="inspect"
 if id=="raid":return stage=="raid_ready"
 if id=="rope":return stage=="rope" and collected.size()==4
 if id.begins_with("bundle"):
  var suffix:=id.trim_prefix("bundle")
  if not suffix.is_valid_int():return false
  var index:=int(suffix)
  return stage=="collect" and index>=0 and index<sites.bundles.size() and index not in collected
 return false
func request(id: String,actor: CharacterBody3D) -> bool:
 if actor!=player or not can_request(id):return false
 if id.begins_with("uniform"):
  disguise_guard=int(id.trim_prefix("uniform"));disguise=outfit.wear(hero,sites.guards[disguise_guard])
  if disguise and disguise_guard not in stripped_guards:stripped_guards.append(disguise_guard)
  return disguise
 if id=="briefing":return begin_cinematic("briefing")
 elif id=="weapons":
  if not player.inventory.has_item("enfield"):player.inventory.add_item("enfield",1)
  player.inventory.add_item("paper_cartridges",12)
  if hero.equipment.selected==1 and not hero.equipment.stowed:hero.equipment.toggle_stowed()
  target_hits=0
  set_stage("load")
 elif id=="raid":return begin_cinematic("raid")
 elif id=="rope":return begin_cinematic("rope")
 elif id.begins_with("bundle"):
  var index=int(id.trim_prefix("bundle"));collected.append(index);sites.bundles[index].hide()
  if collected.size()==4:set_stage("rope")
 return true
func update_raid(delta: float) -> void:
 simulation_elapsed+=delta
 var interval=Budget.interval(sites.raid,player,suspicion>0)
 if simulation_elapsed<interval:return
 var dt=simulation_elapsed;simulation_elapsed=0;guard_age+=dt
 var seen=false
 for i in sites.guards.size():
  var guard: Node3D=sites.guards[i]
  if guard.get_meta("dead",false) or guard.get_meta("knocked_out",false):continue
  if guard.get_meta("grappled",false):continue
  var level=0.0 if i<2 else 3.7
  var goal=sites.raid.to_global(Vector3(-2+i%2*4,level,2 if int(guard_age/12+i)%2==0 else -6))
  move_actor(guard,goal,dt,1.1)
  var holding_bundle: bool=is_instance_valid(player.hold_target) and str(player.hold_target.get("action_id")).begins_with("bundle")
  var suspicious: bool=not disguise or not hero.equipment.stowed or collected.size()>0 or holding_bundle
  if suspicious and Sight.sees(guard,player,13):seen=true
 suspicion=clampf(suspicion+dt*(.65 if seen else -.45),0,1)
 if suspicion>=1:
  outcome="The sentries raised the alarm. Return to the cart and try again."
  player.inventory.message_requested.emit(outcome)
  var witnesses: Array[String]=["magazine_sentry"]
  encounters.record_incident("theft",player.global_position,witnesses,5)
  reset_raid();set_stage("raid_ready")
 # Companions follow the same physical stair route; they never teleport through floors.
 for i in sites.companions.size():
  var companion: Node3D=sites.companions[i]
  var at=sites.raid.to_local(companion.global_position)
  var hero=sites.raid.to_local(player.global_position)
  var goal=player.global_position+Vector3(-1 if i==0 else 1,0,2)
  if hero.y>3 and at.y<3.5:
   if absf(at.x+5)>.7:goal=sites.raid.to_global(Vector3(-5,0,8.5))
   else:goal=sites.raid.to_global(Vector3(-5,clampf((8.5-at.z)/.32*.15,0,3.6),maxf(.8,at.z-.4)))
  if companion.global_position.distance_to(goal)>1.4:move_actor(companion,goal,dt,1.5)
func reset_raid() -> void:
 suspicion=0;collected.clear();sites.rope.hide();sites.cargo.hide()
 for bundle in sites.bundles:bundle.show()
func begin_cinematic(id: String) -> bool:
 if active:return false
 var domains: Array[StringName]=[&"move",&"attack",&"interact",&"board"]
 cinematic_lease=action_service.acquire(self,domains)
 if cinematic_lease<0:return false
 range_transferred=false
 active=true;cinematic=id;age=0;voiced_caption="";voiced_slot=0.0;dialogue_voice.stop();prior_physics=player.is_physics_processing();prior_busy=player.get_meta("document_busy",false)
 player.set_meta("story_cinematic",true);player.set_meta("document_busy",true);player.set_physics_process(false);player.velocity=Vector3.ZERO
 hidden_ui.clear();prior_visibility.clear()
 for path in ["HUD","LandscapeUI","Player/UI","Player/InteractionUI"]:
  var item=world.get_node_or_null(path)
  if item is CanvasItem or item is CanvasLayer:hidden_ui.append(item);prior_visibility.append(item.visible);item.hide()
 for bar in bars:bar.show()
 caption.show();camera.make_current()
 if id=="days":
  sites.set_enabled(true)
  sites.officer.global_position=sites.parking.to_global(Vector3(-5,0,-6))
  if sites.shared_officer:sites.officer.seated=false;sites.officer.seat_weight=0
  sites.officer.foot_plant.clear()
  clock.total_game_minutes+=3*1440
  clock._update_readable_time(true)
 if id=="rescue":
  sites.mangal.riding_cart=sites.coach;sites.mangal.riding_socket=sites.coach.seat_sockets.CoachmanSeat;sites.mangal.driving=true
  sites.horse.set_physics_process(false);sites.horse.pace=2;sites.horse._update_rigged_animation();jump_origin=player.global_position
  sites.coach.rotation.y=sites.horse.rotation.y;sites.coach.global_position=sites.horse.global_position+sites.horse.global_basis.x*3
 if id=="raid":reset_raid()
 if id=="delivery":sites.goods.boarding.set_physics_process(false)
 if id=="rope":
  rope_origin=player.global_position;sites.goods.global_position=ground(sites.raid.to_global(Vector3(0,0,-33)));sites.cargo.show()
 return true
func update_cinematic(delta: float) -> void:
 if cinematic=="range_entry":
  age+=delta
  gameplay_camera.make_current()
  for bar in bars:bar.hide()
  caption.hide()
  shade.color.a=1.0-smoothstep(.55,1.18,age) if age>=.55 else smoothstep(0.0,.48,age)
  if age>=.55 and not range_transferred:
   place_at_firing_line()
   range_transferred=true
  if age>=1.18:finish_cinematic()
  return
 camera.make_current()
 if dialogue_voice.playing and voiced_slot>0.0:
  delta*=minf(1.0,voiced_slot/(dialogue_voice.stream.get_length()+.2))
 age+=delta
 var duration=6.0
 var focus=player.global_position
 var text=""
 match cinematic:
  "days":
   text="A few days later";duration=4
   if age>1.5:player.global_position=sites.tree.global_position+Vector3(0,.9,-4)
  "rescue":
   duration=16
   text="Mangal Pandey: Arjun! You cannot outrun them forever. They will kill you. Come into my carriage!" if age<7 else "Arjun leaves the horse behind and takes shelter inside Mangal’s carriage."
   if age>6 and age<9:
    if sites.horse.rider==player:release_mount(sites.horse);sites.horse.set_process(false)
    var u=clampf((age-6)/3,0,1);var end: Vector3=sites.coach.seat_sockets.RearPassengerRight.global_position
    player.global_position=jump_origin.lerp(end,u)+Vector3.UP*sin(u*PI)*.65
    hero.motion_tree.update_climb(maxf(delta,.04),.14,"flight",u*.58)
    var direction: Vector3=end-jump_origin
    player.visual_root.global_rotation.y=atan2(direction.x,direction.z)
   elif age>=9 and sites.coach.rider!=player:
    release_mount(sites.horse);player.global_position=sites.coach.to_global(Vector3(1.5,1.5,2.26));sites.coach.board_at(player,"RearPassengerRight","passenger")
   if age<6:
    var step: Vector3=-sites.horse.global_basis.z*delta*2;sites.horse.global_position+=step;sites.coach.global_position+=step;jump_origin=player.global_position
   elif age>=9:move_cinematic_cart(sites.coach,2,delta)
   sites.coach.set_forward_motion(2,delta)
   focus=sites.coach.global_position+Vector3.UP*1.6
  "arrival":
   duration=7;text="The old fort · Follow Mangal through the gate";focus=sites.coach.global_position+Vector3.UP
   if uses_fort_gate():
    focus=sites.fort.to_global(Vector3(11.5,4,86))
   else:
    move_cinematic_cart(sites.coach,1.4,delta);sites.coach.set_forward_motion(1.4,delta)
  "briefing":
   duration=19;focus=sites.mangal.global_position+Vector3.UP
   preload("res://story/conversation_facing.gd").pair(player,sites.mangal)
   text="Mangal Pandey: Anger alone will not win this war. Bare hands cannot answer their guns." if age<7 else "Mangal Pandey: We gather weapons, train together, and choose our moment. Learn to load and shoot before you risk another life." if age<14 else "Mangal Pandey: Take one of the Enfields from the rack. Equip it, then I will show you how to aim and fire."
  "raid":
   duration=6;text="Cantonment · The weapons magazine";focus=sites.raid.global_position+Vector3.UP*3
   if age>2:
    release_mount((player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null));sites.goods.global_position=ground(sites.raid.to_global(Vector3(0,0,24)));player.global_position=sites.goods.global_position+Vector3(3,.9,0)
    for i in 2:sites.companions[i].global_position=player.global_position+Vector3(-2+i*4,-.9,2);reset_grounding(sites.companions[i])
  "rope":
   duration=18;text="The bundles are secured. Cross the rope to the boundary wall, then jump to the cart.";sites.rope.show()
   var rope_start: Vector3=sites.raid.to_global(Vector3(0,5.5,-10));var rope_end: Vector3=sites.raid.to_global(Vector3(0,4.5,-22))
   var start: Vector3=rope_start-Vector3.UP*.85-Vector3(0,0,.5);var end: Vector3=rope_end-Vector3.UP*.85+Vector3(0,0,.5)
   var visual: Node=hero
   if age<2:
    var u=smoothstep(0,2,age);player.global_position=rope_origin.lerp(start,u)+Vector3.UP*sin(PI*u)*.7
   elif age<8:
    var u=clampf((age-2)/6,0,1);player.global_position=start.lerp(end,u)
    visual.motion_tree.update_climb(delta,.14)
    pose_rope_contact(rope_start.lerp(rope_end,u),(rope_end-rope_start).normalized())
   elif age<11:
    visual.motion_tree.release_climb(delta)
    var u=clampf((age-8)/3,0,1);var landing: Vector3=sites.goods.seat_sockets.DriverSeat.global_position
    player.global_position=(end+Vector3.UP*.6).lerp(landing,u)+Vector3.UP*sin(PI*u)*.8
   elif sites.goods.rider!=player:
    player.global_position=sites.goods.seat_sockets.DriverSeat.global_position;sites.goods.board_at(player,"DriverSeat","driver")
   for i in 2:
    var companion: Node3D=sites.companions[i];var u=clampf((age-4-i*3)/6,0,1)
    if age<4+i*3:continue
    if u<1:
     companion.global_position=start.lerp(end,u)-Vector3.UP*.9;companion.rope_contact=rope_start.lerp(rope_end,u);companion.rope_axis=(rope_end-rope_start).normalized()
    elif age<13+i*2:
     companion.rope_contact=Vector3.ZERO;var jump=clampf((age-10-i*3)/3,0,1)
     companion.global_position=(end-Vector3.UP*.9).lerp(sites.cargo_seats[i].global_position,jump)+Vector3.UP*sin(PI*jump)*.6
    else:
     companion.rope_contact=Vector3.ZERO;companion.riding_cart=sites.goods;companion.riding_socket=sites.cargo_seats[i]
   focus=(start+end)*.5 if age<11 else sites.goods.global_position+Vector3.UP
  "delivery":
   duration=7;text="Mangal Pandey’s hideout · The captured rifles have arrived.";focus=sites.goods.global_position+Vector3.UP
   sites.parking_material.albedo_color.a=maxf(0,1-age/1.5)
 caption.text=text
 if delta>0.0 and text!=voiced_caption:
  dialogue_voice.stop();voiced_caption=text;voiced_slot=0.0
  if text.begins_with("Mangal Pandey: "):
   var spoken: String=text.trim_prefix("Mangal Pandey: ")
   var key: String=("Mangal Pandey\n"+spoken).sha256_text()
   var path: String="res://assets/audio/dialogue/"+key+".wav"
   if ResourceLoader.exists(path):
    var stream:=load(path) as AudioStream
    if stream!=null:
     dialogue_voice.stream=stream
     voiced_slot=5.0 if cinematic=="briefing" and age>=14.0 else 7.0
     dialogue_voice.play()
 shade.color.a=1.0 if cinematic=="days" else maxf(1-smoothstep(0,1,age),smoothstep(duration-1,duration,age))
 title_card.text="A few days later" if cinematic=="days" else "Mangal Pandey’s hideout" if cinematic in ["arrival","delivery"] else "Cantonment · Weapons magazine" if cinematic=="raid" else ""
 title_card.visible=not title_card.text.is_empty() and (cinematic=="days" or shade.color.a>.65)
 caption.visible=cinematic!="days"
 camera.global_position=focus+Vector3(5,2.8,6)
 if cinematic=="rescue":camera.global_position=focus-sites.coach.global_basis.x*7+sites.coach.global_basis.z*3+Vector3.UP*2.2
 camera.look_at(focus)
 if age>=duration:finish_cinematic()
func pose_rope_contact(anchor: Vector3,axis: Vector3) -> void:
 var rig: Skeleton3D=hero.skeleton;var equipment: Node=hero.equipment
 var shoulders:=Vector3.ZERO
 for side in ["l","r"]:shoulders+=rig.to_global(rig.get_bone_global_pose(hero.bones["upperarm_"+side]).origin)*.5
 player.global_position+=anchor-Vector3.UP*.3-shoulders
 rig.force_update_all_bone_transforms()
 rope_contact_error=0
 for side in ["l","r"]:
  var sign_side:=1.0 if side=="l" else -1.0
  var target:=anchor+axis*sign_side*.16+Vector3.RIGHT*sign_side*.025
  var inward:=Vector3.RIGHT*(-sign_side);var forward:=axis;var across:=forward.cross(inward).normalized()
  var desired: Basis=rig.global_basis.inverse()*Basis(across,forward,inward)*(equipment.palm_axes[side] as Basis).inverse()
  var index: int=hero.bones["hand_"+side];var parent:=rig.get_bone_parent(index)
  var local_target:=rig.to_local(target)
  for iteration in 2:
   equipment._solve_arm(side,local_target-desired*equipment.palm_offsets[side])
   rig.set_bone_pose_rotation(index,(rig.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion());rig.force_update_all_bone_transforms()
  equipment._grasp(side,.8)
  var palm:=rig.to_global(rig.get_bone_global_pose(index)*equipment.palm_offsets[side])
  rope_contact_error=maxf(rope_contact_error,palm.distance_to(target))
func move_cinematic_cart(cart: Node3D,speed: float,delta: float) -> void:
 var remaining:=speed*delta
 while remaining>.001:
  var step:=minf(.2,remaining);remaining-=step
  var next: Vector3=cart.global_position-cart.global_basis.z*step
  var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*4,next-Vector3.UP*4,1);ray.exclude=cart.boarding._vehicle_exclusions()
  var floor_hit:=cart.get_world_3d().direct_space_state.intersect_ray(ray)
  if not floor_hit.is_empty():next.y=floor_hit.position.y+.02
  if not cart.boarding._clearance_at(next):break
  cart.global_position=next
func release_mount(mount: Node) -> void:
 if not is_instance_valid(mount):return
 if "cart" in mount:mount=mount.cart
 if mount is CharacterBody3D:
  player.collision_layer=mount.saved_layer;player.collision_mask=mount.saved_mask;mount.rider=null;mount.transition="";mount.pace=0;mount.velocity=Vector3.ZERO
 else:
  player.collision_layer=mount.boarding.saved_layer;player.collision_mask=mount.boarding.saved_mask;mount.boarding.rider=null;mount.boarding.transition="";mount.boarding.speed=0
 player.set_meta("mounted_vehicle",null);player.set_meta("horse_transition","")
func finish_cinematic() -> void:
 dialogue_voice.stop()
 preload("res://story/conversation_facing.gd").release(player)
 preload("res://story/conversation_facing.gd").release(sites.mangal)
 action_service.release(cinematic_lease);cinematic_lease=-1
 var was=cinematic;active=false;cinematic="";caption.hide();title_card.hide();shade.color.a=0;gameplay_camera.make_current()
 for bar in bars:bar.hide()
 player.set_meta("story_cinematic",false);player.set_meta("document_busy",prior_busy);player.set_physics_process(prior_physics)
 for i in hidden_ui.size():hidden_ui[i].visible=prior_visibility[i]
 hero.motion_tree.set_melee(0,-1)
 hero.motion_tree.release_climb(1.0)
 match was:
  "days":set_stage("ambush")
  "rescue":
   release_mount(sites.coach);sites.horse.set_physics_process(true);sites.horse.set_process(true)
   sites.coach.global_position=ground(sites.fort.to_global(Sites.GATE_COACH_PARK if uses_fort_gate() else Vector3(0,0,65)))
   player.global_position=sites.coach.global_position+Vector3(3,.9,0)
   encounters.complete_custody(player)
   follow_index=0;begin_cinematic("arrival")
  "arrival":
   sites.mangal.riding_socket=null;sites.mangal.riding_cart=null;sites.mangal.driving=false
   var start:Vector3=sites.fort.to_global(Vector3(11.5,0,91)) if uses_fort_gate() else sites.cellar.to_global(Vector3(0,0,34))
   sites.mangal.global_position=ground(start)
   player.global_position=ground(start+Vector3(2,0,2))+Vector3.UP*.9 if uses_fort_gate() else sites.mangal.global_position+Vector3(2,.9,2)
   predecessor.reset_actor_grounding(sites.mangal) if predecessor.has_method("reset_actor_grounding") else sites.mangal.foot_plant.clear()
   set_stage("follow")
  "briefing":set_stage("inspect")
  "range_entry":enter_range()
  "raid":set_stage("infiltrate")
  "rope":
   sites.cargo.show()
   for i in 2:sites.companions[i].riding_cart=sites.goods;sites.companions[i].riding_socket=sites.cargo_seats[i]
   if sites.goods.rider!=player:
    player.global_position=sites.goods.seat_sockets.DriverSeat.global_position;sites.goods.board_at(player,"DriverSeat","driver")
   for i in 2:sites.companions[i].global_position=player.global_position+Vector3(i*1.5,-.9,2)
   set_stage("return")
  "delivery":
   sites.return_bay.hide();sites.goods.boarding.set_physics_process(true)
   for i in 2:sites.companions[i].riding_socket=null;sites.companions[i].global_position=sites.goods.global_position+Vector3(-2+i*4,0,4)
   captured_rifles=12;set_stage("complete");player.inventory.add_item("paper_cartridges",12);player.inventory.message_requested.emit("Mission complete · Twelve captured rifles delivered to Mangal’s hideout.")
func export_state() -> Dictionary:
 if not configured:return pending_restore.duplicate(true) if restore_waiting else {"stage":"dormant"}
 var actors: Array=[]
 for actor in [sites.officer,sites.mangal]+sites.guards+sites.companions:
  var at: Vector3=actor.global_position
  actors.append({"position":[at.x,at.y,at.z],"heading":actor.rotation.y,"health":actor.get_node("Vitality").health,"dead":actor.get_meta("dead",false),"knocked_out":actor.get_meta("knocked_out",false)})
 return {"hideout_daily":sites.cellar.get_node("HideoutDailyLife").export_state(),"actors":actors,"stage":stage,"collected":collected.duplicate(),"disguise":disguise,"disguise_guard":disguise_guard,"stripped_guards":stripped_guards.duplicate(),"captured_rifles":captured_rifles,"target_hits":target_hits,"reload_seen":reload_seen,"officer_age":officer_age,"follow_index":follow_index,"fort_gate_route":uses_fort_gate()}
func restore_state(data: Dictionary) -> void:
 if not configured:
  pending_restore=data.duplicate(true);restore_waiting=true;return
 stage=str(data.get("stage","dormant"));if stage not in STAGES:stage="dormant"
 var daily:Node=sites.cellar.get_node_or_null("HideoutDailyLife")
 if daily!=null:daily.restore_state(data.get("hideout_daily",{}) if data.get("hideout_daily",{}) is Dictionary else {})
 collected.clear()
 for value in data.get("collected",[]):
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:continue
  var index=int(value)
  if index>=0 and index<4 and index not in collected:collected.append(index)
 disguise_guard=clampi(int(data.get("disguise_guard",0)),0,3)
 disguise=bool(data.get("disguise",false));target_hits=clampi(int(data.get("target_hits",0)),0,2);reload_seen=bool(data.get("reload_seen",false));officer_age=maxf(0,float(data.get("officer_age",0)));follow_index=int(data.get("follow_index",0))
 if stage=="follow" and uses_fort_gate() and not data.get("fort_gate_route",false):follow_index+=GATE_FOLLOW_ROUTE.size()
 follow_index=clampi(follow_index,0,follow_route_size()-1)
 stripped_guards.clear()
 for value in data.get("stripped_guards",[]):
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:continue
  var index:=int(value)
  if index>=0 and index<4 and index not in stripped_guards:stripped_guards.append(index)
 captured_rifles=12 if stage=="complete" and collected.size()==4 else 0
 sites.set_enabled(stage!="dormant")
 if disguise:outfit.wear(hero,sites.guards[disguise_guard])
 else:outfit.remove()
 for i in stripped_guards:outfit.strip_guard(hero,sites.guards[i])
 var roster=[sites.officer,sites.mangal]+sites.guards+sites.companions
 var records: Array=data.get("actors",[]) if data.get("actors",[]) is Array else []
 for i in mini(roster.size(),records.size()):
  if not records[i] is Dictionary:continue
  var actor: Node3D=roster[i];var record: Dictionary=records[i];var coords: Array=record.get("position",[])
  if coords.size()==3:
   var at:=Vector3(float(coords[0]),float(coords[1]),float(coords[2]))
   if at.is_finite():actor.global_position=at
  actor.rotation.y=float(record.get("heading",0));actor.get_node("Vitality").health=clampf(float(record.get("health",75)),0,75)
  var dead: bool=record.get("dead",false);var knocked: bool=record.get("knocked_out",false)
  actor.get_node("Vitality").dead=dead;actor.set_meta("dead",dead);actor.set_meta("knocked_out",knocked)
  actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",dead or knocked)
  if dead or knocked:actor.combat_react("down")
 sites.cargo.visible=stage in ["return","complete"]
 if stage=="return":
  for i in 2:sites.companions[i].riding_cart=sites.goods;sites.companions[i].riding_socket=sites.cargo_seats[i]
 for i in sites.bundles.size():sites.bundles[i].visible=i not in collected
 if stage in ["escape","follow","briefing","inspect","load","shoot","raid_ready","infiltrate","collect","rope","return","complete"]:
  sites.officer.get_node("Vitality").dead=true;sites.officer.set_meta("dead",true);sites.officer.hide()
 if stage=="shoot" and target_hits>=1:
  set_stage("raid_ready")
 elif stage=="shoot":
  place_at_firing_line()
  enter_range()
 else:set_stage(stage)
func _exit_tree() -> void:
 if is_instance_valid(action_service):
  action_service.release(cinematic_lease)
  if range_lease>=0:release_range()
 outfit.remove()
 if is_instance_valid(clock):clock.set_mission_daylight_locked(&"mangal_weapon_training",false)
 if is_instance_valid(player) and active:
  player.set_meta("story_cinematic",false);player.set_meta("document_busy",prior_busy);player.set_physics_process(prior_physics)
  for i in hidden_ui.size():
   if is_instance_valid(hidden_ui[i]):hidden_ui[i].visible=prior_visibility[i]
  if is_instance_valid(gameplay_camera):gameplay_camera.make_current()

func cart_in_delivery_bay() -> bool:
 for collision in sites.goods.boarding.clearance_shapes:
  if not collision.shape is BoxShape3D:continue
  var half: Vector3=collision.shape.size*.5
  for corner in [Vector3(-half.x,0,-half.z),Vector3(half.x,0,-half.z),Vector3(half.x,0,half.z),Vector3(-half.x,0,half.z)]:
   var at: Vector3=sites.return_bay.to_local(collision.to_global(corner))
   if absf(at.x)>2.9 or absf(at.z)>5.9:return false
 return true
func rear_target() -> Node3D:
 if not configured or active or stage not in ["infiltrate","collect"]:return null
 for guard in sites.guards:
  if guard.get_meta("dead",false) or guard.get_meta("knocked_out",false) or guard.get_meta("grappled",false) or guard.travel_speed>.2:continue
  var offset: Vector3=player.global_position-guard.global_position;offset.y=0
  if offset.length()<.48 or offset.length()>1.05 or offset.normalized().dot(guard.global_basis.z)>-.6:continue
  return guard
 return null
func skip_cinematic() -> void:
 if not active or cinematic=="range_entry":return
 dialogue_voice.stop()
 player.set_meta("cinematic_jump_block_until_released",true)
 # Resolve connected travel shots through their normal endpoints, stopping at gameplay.
 for transition in 3:
  if not active:return
  var durations={"days":4.0,"rescue":16.0,"arrival":7.0,"briefing":19.0,"raid":6.0,"rope":18.0,"delivery":7.0}
  age=float(durations.get(cinematic,6.0))
  update_cinematic(0.0)

func _input(event: InputEvent) -> void:
 if range_lease>=0:
  if event.is_action("aim") or event.is_action("attack") or event is InputEventMouseMotion or event is InputEventJoypadMotion:return
  if event.is_pressed():get_viewport().set_input_as_handled()
  return
 if active and event.is_action_pressed("jump") and not event.is_echo():
  skip_cinematic();get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Q and rear_target()!=null:
  if grapple.begin():get_viewport().set_input_as_handled()
