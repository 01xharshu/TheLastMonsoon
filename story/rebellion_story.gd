extends Node3D
## Saved continuation after Chacha's final lesson. No completion by proximity alone.
const Startup=preload("res://systems/world_startup.gd")
const Sites=preload("res://story/rebellion_sites.gd")
const Sight=preload("res://systems/visual_perception.gd")
const Actions=preload("res://systems/action_permissions.gd")
const Budget=preload("res://systems/simulation_budget.gd")
const STAGES=["dormant","ambush","confront","escape","follow","briefing","inspect","load","shoot","raid_ready","infiltrate","collect","rope","return","complete"]
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
var age=0.0
var suspicion=0.0
var disguise=false
var disguise_guard=0
var stripped_guards: Array[int]=[]
var captured_rifles=0
var outfit=preload("res://story/rebellion_disguise.gd").new()
var collected: Array[int]=[]
var target_hits=0
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
  "inspect":return "Inspect the captured weapons."
  "load":return "Select the Enfield (2), draw it (H), then load a paper cartridge (R)."
  "shoot":return "Aim at the wooden target and fire. Reload and hit it twice."
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
  "load","shoot":at=sites.target.global_position
  "infiltrate":at=sites.raid.to_global(Vector3(-5,3.7,-3))
  "collect":
   for i in sites.bundles.size():
    if i not in collected:at=sites.bundles[i].global_position;break
  "rope":at=sites.prompts.rope.global_position
  "return":at=sites.return_bay.global_position
  "complete":return {}
 return {"position":at+Vector3.UP,"label":objective(),"endpoint":""}
func set_stage(next: String) -> void:
 stage=next;age=0
 clock.set_mission_daylight_locked(&"mangal_weapon_training",stage in ["inspect","load","shoot"])
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
   var gun: Node=rifle
   if gun.reload_remaining>0:reload_seen=true
   if reload_seen and gun.reload_remaining==0 and gun.rounds>0:set_stage("shoot");starting_shots=gun.shots_fired
  "shoot":
   if target_hits>=2:set_stage("raid_ready")
  "infiltrate","collect":
   update_raid(delta)
   if stage=="infiltrate" and near(sites.raid.to_global(Vector3(-2,4.6,-4)),6) and player.global_position.y>sites.raid.global_position.y+3:set_stage("collect")
  "return":
   sites.return_bay.visible=player.global_position.distance_to(sites.return_bay.global_position)<45
   sites.parking_material.albedo_color.a=move_toward(sites.parking_material.albedo_color.a,1,delta*2)
   var local: Vector3=sites.return_bay.to_local(sites.goods.global_position)
   if sites.goods.rider==player and cart_in_delivery_bay() and absf(sites.goods.boarding.speed)<.35:
    begin_cinematic("delivery")
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
func move_actor(actor: Node3D,goal: Vector3,delta: float,speed: float) -> bool:
 var offset=goal-actor.global_position
 if offset.length()<.2:actor.travel_speed=0;return true
 var step=offset.normalized()*minf(speed*delta,offset.length())
 var query=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.9,actor.global_position+step+Vector3.UP*.9,1);query.exclude=[actor.body_collider.get_rid(),actor.get_node("Vitality").hit_body.get_rid()]
 if not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():actor.travel_speed=0;return false
 actor.global_position+=step;actor.rotation.y=atan2(offset.x,offset.z);actor.travel_speed=speed;return false
func advance_follow(delta: float) -> void:
 var goals=[sites.cellar.to_global(Vector3(0,3.8,24)),sites.cellar.to_global(Vector3(0,3.8,18)),sites.cellar.to_global(Vector3(0,.2,7)),sites.cellar.to_global(Vector3(-3,.2,2))]
 if not near(sites.mangal.global_position,9):sites.mangal.travel_speed=0;return
 if move_actor(sites.mangal,goals[follow_index],delta,1.4):
  follow_index+=1
  if follow_index==goals.size():set_stage("briefing")
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
 if id.begins_with("bundle"):return stage=="collect" and int(id.trim_prefix("bundle")) not in collected
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
  player.inventory.add_item("paper_cartridges",12);rifle.rounds=0;rifle.loaded=false;reload_seen=false;set_stage("load")
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
 active=true;cinematic=id;age=0;prior_physics=player.is_physics_processing();prior_busy=player.get_meta("document_busy",false)
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
 camera.make_current()
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
   duration=7;text="The ruined fort · Mangal Pandey’s hideout";focus=sites.coach.global_position+Vector3.UP
   move_cinematic_cart(sites.coach,1.4,delta);sites.coach.set_forward_motion(1.4,delta)
  "briefing":
   duration=19;focus=sites.mangal.global_position+Vector3.UP
   text="Mangal Pandey: Anger alone will not win this war. Bare hands cannot answer their guns." if age<7 else "Mangal Pandey: We gather weapons, train together, and choose our moment. Learn to load and shoot before you risk another life." if age<14 else "Mangal Pandey: These rifles were taken from Company stores. You will help us bring the next shipment home."
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
   sites.coach.global_position=ground(sites.fort.to_global(Vector3(0,0,65)))
   player.global_position=sites.coach.global_position+Vector3(3,.9,0)
   encounters.complete_custody(player)
   follow_index=0;begin_cinematic("arrival")
  "arrival":
   sites.mangal.riding_socket=null;sites.mangal.riding_cart=null;sites.mangal.driving=false
   sites.mangal.global_position=ground(sites.cellar.to_global(Vector3(0,0,34)));player.global_position=sites.mangal.global_position+Vector3(2,.9,2)
   predecessor.reset_actor_grounding(sites.mangal) if predecessor.has_method("reset_actor_grounding") else sites.mangal.foot_plant.clear()
   set_stage("follow")
  "briefing":set_stage("inspect")
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
 return {"actors":actors,"stage":stage,"collected":collected.duplicate(),"disguise":disguise,"disguise_guard":disguise_guard,"stripped_guards":stripped_guards.duplicate(),"captured_rifles":captured_rifles,"target_hits":target_hits,"reload_seen":reload_seen,"officer_age":officer_age,"follow_index":follow_index}
func restore_state(data: Dictionary) -> void:
 if not configured:
  pending_restore=data.duplicate(true);restore_waiting=true;return
 stage=str(data.get("stage","dormant"));if stage not in STAGES:stage="dormant"
 collected.clear()
 for value in data.get("collected",[]):
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:continue
  var index=int(value)
  if index>=0 and index<4 and index not in collected:collected.append(index)
 disguise_guard=clampi(int(data.get("disguise_guard",0)),0,3)
 disguise=bool(data.get("disguise",false));target_hits=clampi(int(data.get("target_hits",0)),0,2);reload_seen=bool(data.get("reload_seen",false));officer_age=maxf(0,float(data.get("officer_age",0)));follow_index=clampi(int(data.get("follow_index",0)),0,3)
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
 set_stage(stage)
func _exit_tree() -> void:
 if is_instance_valid(action_service):action_service.release(cinematic_lease)
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
func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Q and rear_target()!=null:
  if grapple.begin():get_viewport().set_input_as_handled()
