extends Node3D
## Independent camp roles. Mission actors retain their story/cinematic ownership.
const Budget=preload("res://systems/simulation_budget.gd")
const Activity=preload("res://characters/npcs/activity_actor.gd")
const Rebel=preload("res://story/rebellion_actor.gd")
const Human=preload("res://characters/human_scene.gd")
const SOURCE="res://characters/npcs/mangal_rebels/mangal_rebel.glb"
const JOBS=["watch_roof_left","watch_roof_right","gate_watch","seated_talk","seated_listen","relax","sleep","carry_supplies","mangal_listener","sleep_right","gun_cleaner","cook","drinker","drinking_partner"]
var sites:Node
var director:Node
var player:CharacterBody3D
var records:Array[Dictionary]=[]
var next_spawn:=0
var spawn_wait:=0.0
var elapsed:=0.0
var mangal_seat:Node3D
var seat_owned:=false
var last_training:=false
var saved_roles:Dictionary={}
var sweep_shape:=CapsuleShape3D.new()
var routine_clock:=0.0
var routine_tick:=0.0
var mangal_task:="discussion"
var planning_map:Node3D
var remote_visuals:=false
var mangal_visual_suspended:=false

func setup(owner:Node) -> void:
 sites=owner;director=sites.director;player=director.player
 name="HideoutDailyLife"

func _ready() -> void:
 process_priority=110
 sweep_shape.radius=.27;sweep_shape.height=1.4
 # Seat and partner keep the original named Mangal and briefing prompt.
 var bench:Node3D=sites.b.piece(self,"MangalDiscussionChair",Vector3(-3,.38,2),Vector3(.59,.1,.62),sites.b.wood,false)
 for x in [-.23,.23]:
  for z in [-.24,.24]:
   sites.b.piece(bench,"ChairLeg",Vector3(x,-.12,z),Vector3(.065,.25,.065),sites.b.wood,false)
 for z in [-.24,.24]:
  sites.b.piece(bench,"ChairBackUpright",Vector3(-.25,.25,z),Vector3(.065,.54,.065),sites.b.wood,false)
 for height in [.24,.43]:
  sites.b.piece(bench,"ChairBackRail",Vector3(-.25,height,0),Vector3(.05,.09,.52),sites.b.wood,false)
 mangal_seat=Node3D.new();mangal_seat.name="MangalDiscussionSeat";bench.add_child(mangal_seat);mangal_seat.position=Vector3(0,.12,0);mangal_seat.rotation.y=-PI*.5
 var paper:=StandardMaterial3D.new();paper.albedo_color=Color("b7a67a");paper.roughness=1.0
 planning_map=sites.b.piece(sites.mangal,"FoldedPlanningMap",Vector3(0,.72,.32),Vector3(.42,.008,.27),paper,false)
 planning_map.visible=false


func _process(delta:float) -> void:
 if not is_instance_valid(director) or not director.configured:return
 var stage:String=director.stage
 if next_spawn<JOBS.size() and stage not in ["dormant","ambush","confront","escape"]:
  spawn_wait-=delta
  if spawn_wait<=0.0:
   spawn_person(next_spawn);next_spawn+=1;spawn_wait=.2
 var present:bool=stage not in ["dormant","ambush","confront","escape"]
 var training:bool=present and stage in ["inspect","load","shoot"]
 if training!=last_training or sites.trainees.any(func(t):return is_instance_valid(t) and t.visible!=training):
  for trainee in sites.trainees:
   if not is_instance_valid(trainee):continue
   trainee.visible=training;trainee.set_process(training)
   trainee.body_collider.collision_layer=1 if training else 0
   trainee.get_node("Vitality").hit_body.collision_layer=8 if training else 0
  last_training=training
 # The two raid companions are story-owned and become visible for the raid;
 # idle hideout life uses the separately assigned camp residents instead.
 var companions_needed:bool=stage in ["raid_ready","infiltrate","collect","rope","return"] or director.cinematic in ["raid","rope","delivery"]
 for companion in sites.companions:
  if not is_instance_valid(companion) or companion.visible==companions_needed:continue
  companion.visible=companions_needed;companion.set_process(companions_needed)
  companion.body_collider.collision_layer=1 if companions_needed else 0
  companion.get_node("Vitality").hit_body.collision_layer=8 if companions_needed else 0
 # Training is an explicit temporary assignment; ordinary camp residents are
 # kept away from the target and can remain active during the lesson.
 var consignment:Node=director.world.get_node_or_null("ConsignmentStory")
 var community:Node=director.world.get_node_or_null("CommunityStory")
 var player_talking:bool=community!=null and community.conversation_partner==sites.mangal
 var free_mangal:bool=present and stage=="complete" and not director.active and not player.get_meta("story_cinematic",false) and not player_talking and not sites.mangal.get_meta("dead",false) and (consignment==null or consignment.stage in ["dormant","assigned","complete","failed"])
 for record in records:
  var actor:Node3D=record.actor
  var enabled:bool=present and (record.job!="mangal_listener" or free_mangal)
  if actor.visible!=enabled:
   actor.visible=enabled
   var alive:bool=not actor.get_meta("dead",false) and not actor.get_meta("knocked_out",false)
   actor.body_collider.collision_layer=1 if enabled and alive else 0
   actor.get_node("Vitality").hit_body.collision_layer=8 if enabled and alive else 0
 var briefing:bool=director.cinematic=="briefing"
 sites.mangal.set_meta("mangal_briefing",briefing)
 update_mangal_seat(free_mangal or briefing)
 if mangal_visual_suspended and not free_mangal:
  sites.mangal.set_process(true);sites.mangal.animation_tree.active=true;mangal_visual_suspended=false
 if not present:
  planning_map.visible=false;sites.mangal.set_meta("hideout_task","")
  if is_instance_valid(sites.mangal.held_rifle):sites.mangal.held_rifle.visible=true
  return
 elapsed+=delta
 routine_clock+=delta
 routine_tick+=delta
 # Logical schedules keep time while expensive contact and animation sleep.
 var distant:bool=Budget.interval(self,player)>=.5
 if distant!=remote_visuals:
  remote_visuals=distant
  for record in records:
   record.actor.set_process(not distant and record.job in ["watch_roof_left","watch_roof_right","gate_watch"])
   record.actor.animation_tree.active=not distant
 if free_mangal:
  var tasks=["discussion","planning","rifle_check","rest"]
  mangal_task=tasks[int(routine_clock/38.0)%tasks.size()]
  sites.mangal.set_meta("hideout_task",mangal_task)
 else:
  sites.mangal.set_meta("hideout_task","")
 planning_map.visible=free_mangal and mangal_task=="planning"
 if is_instance_valid(sites.mangal.held_rifle):sites.mangal.held_rifle.visible=not free_mangal or mangal_task=="rifle_check"
 if distant and free_mangal:
  sites.mangal.set_process(false);sites.mangal.animation_tree.active=false;mangal_visual_suspended=true
 elif mangal_visual_suspended:
  sites.mangal.set_process(true);sites.mangal.animation_tree.active=true;mangal_visual_suspended=false
 if distant and routine_tick<.5:return
 var routine_step:float=routine_tick;routine_tick=0.0
 for record in records:
  var actor:Node3D=record.actor
  if not actor.visible or actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):continue
  record.pending+=routine_step
  if record.pending<Budget.interval(actor,player):continue
  var step:float=record.pending;record.pending=0.0
  if distant:continue
  if record.job=="carry_supplies":
   # Substep physical sweeps so remote accumulated time cannot cross obstacles.
   while step>0.0:
    var slice:=minf(step,.1);step-=slice;advance_carrier(record,slice)
  elif actor is Activity:
   if record.job in ["sleep","sleep_right"]:
    var spine:int=actor._skeleton.find_bone("spine_02")
    if spine>=0:actor._skeleton.set_bone_pose_rotation(spine,actor._base_rotations["spine_02"]*Quaternion(actor._pitch_axes["spine_02"],.018*sin(elapsed*1.6)))
    continue
   if record.job in ["gun_cleaner","cook","drinker","drinking_partner"]:
    update_work(record,step)
    continue
   actor.perform("read",step,(record.job=="seated_talk" or record.job=="mangal_listener") and fposmod(elapsed,7.0)<3.5)
   if record.job=="relax":
    for side in ["l","r"]:
     actor.solve_hand_contact(side,actor.to_global(Vector3(.15 if side=="l" else -.15,.54,.28)));actor.set_grip(side,.12)
   if record.job=="mangal_listener":
    var offset:Vector3=sites.mangal.global_position-actor.global_position;actor.rotation.y=atan2(offset.x,offset.z)
    var head:int=actor._skeleton.find_bone("head")
    if head>=0:actor._skeleton.set_bone_pose_rotation(head,actor._base_rotations["head"]*Quaternion(actor._pitch_axes["head"],.025*sin(elapsed*2)))
    var arm:int=actor._skeleton.find_bone("upperarm_r")
    if arm>=0:actor._skeleton.set_bone_pose_rotation(arm,actor._base_rotations["upperarm_r"]*Quaternion(actor._pitch_axes["upperarm_r"],-.3-.12*sin(elapsed*2)))
   if record.job in ["seated_talk","seated_listen"]:
    var other:Node3D=records[4].actor if record.job=="seated_talk" and records.size()>4 else records[3].actor if records.size()>3 else null
    if is_instance_valid(other):
     var offset:Vector3=other.global_position-actor.global_position;actor.rotation.y=atan2(offset.x,offset.z)
    if record.job=="seated_talk":
     var bone:int=actor._skeleton.find_bone("upperarm_r")
     if bone>=0:actor._skeleton.set_bone_pose_rotation(bone,actor._base_rotations["upperarm_r"]*Quaternion(actor._pitch_axes["upperarm_r"],-.38-.1*sin(elapsed*2)))
   actor.finish_contacts()

func spawn_person(index:int) -> void:
 var job:String=JOBS[index]
 var guard:bool=job in ["watch_roof_left","watch_roof_right","gate_watch"]
 var actor:Node3D=Rebel.new() if guard else Activity.new()
 actor.name="Camp_"+job;actor.movement_enabled=false
 actor.set_meta("world_role",job);actor.set_meta("population_expansion_exempt",true);actor.set_meta("human_source",SOURCE);actor.set_meta("combat_faction","indian")
 actor.add_child(Human.instantiate(SOURCE));add_child(actor)
 var positions=[Vector3(-7.0,4.06,-4.5),Vector3(7.0,4.06,-4.5),Vector3(3.0,3.7,22.0),Vector3(4.4,.2,1.7),Vector3(6.0,.2,1.7),Vector3(-6.3,.2,.4),Vector3(-7.7,.44,2.6),Vector3(-2.15,3.7,20.0),Vector3(-4.3,.2,2.0),Vector3(7.7,.44,2.6),Vector3(5.3,.2,-3.8),Vector3(-4.8,.2,-5.4),Vector3(-4.8,.2,5.2),Vector3(-6.0,.2,5.2)]
 actor.position=positions[index]
 if job=="watch_roof_right" and sites.fort.get("embedded_in_world")==true:
  var keep_height:float=sites.fort.height_at(0,-47)+.7
  actor.global_position=sites.fort.to_global(Vector3(2.4,keep_height,-46.3))
  actor.set_meta("world_role","keep_lookout")
 if job=="gate_watch":
  actor.rotation.y=PI
  if sites.fort.get("embedded_in_world")==true:
   actor.global_position=sites.fort.to_global(Vector3(15.0,sites.fort.entrance_ground(15.0,81.0),81.0))
 if guard:
  actor.viewer=player;sites.equip(actor);actor.set_process(true)
 else:
  actor.set_process(false);actor.ground_height=func(_x:float,_z:float)->float:return actor.global_position.y
  if job in ["seated_talk","seated_listen","relax","mangal_listener","gun_cleaner","cook","drinker","drinking_partner"]:
   actor.seat_height=.43
   sites.b.piece(self,"CampSeat",actor.position+Vector3(0,.22,0),Vector3(.54,.44,.54),sites.b.wood,true)
  if job in ["sleep","sleep_right"]:
   # The complete dressed body lies on an existing bedroll, feet at its foot.
   actor.rotation.x=PI*.5;actor.rotation.y=0;actor._set_animation(&"idle",0.0)
  if job=="carry_supplies":
   # The shared foot solver was configured before the actor was placed on
   # the raised terrace. Rebase its planted ankle heights to that surface.
   actor._skeleton.force_update_all_bone_transforms()
   for side in ["l","r"]:
    var ankle:int=actor._skeleton.find_bone("foot_"+side)
    actor.foot_plant.ankle_height[side]=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(ankle).origin).y
   var load:Node3D=sites.b.piece(actor,"CarriedSupplyCrate",Vector3(0,1.0,.30),Vector3(.48,.34,.36),sites.b.wood,false)
   actor.set_meta("carried_load",load)
  var delivered:Node3D=sites.b.piece(self,"DeliveredSupplyCrate",Vector3(-2.15,3.87,23.05),Vector3(.48,.34,.36),sites.b.wood,false)
  delivered.visible=false;actor.set_meta("delivered_load",delivered)
 if job=="gun_cleaner":
  var rifle:Node3D=load("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
  rifle.name="RebelEnfield";actor.add_child(rifle)
 if job=="cook":
  var cooking:Node3D=load("res://objects/household/sets/cooking_corner.tscn").instantiate()
  cooking.name="CampCookingHearth";add_child(cooking);cooking.position=Vector3(-4.8,.2,-4.35)
  var spatula:Node3D=sites.b.piece(actor,"WoodenCookingSpatula",Vector3.ZERO,Vector3(.045,.025,.65),sites.b.wood,false)
  actor.set_meta("cooking_tool",spatula);actor.set_meta("cooking_surface",cooking.get_node("CookingSurface"))
 if job=="drinker":
  var cup:Node3D=load("res://objects/household/water_pot_visual.tscn").instantiate()
  cup.name="CampDrinkingCup";actor.add_child(cup);cup.scale=Vector3.ONE*.22
  actor.set_meta("work_prop",cup)
 actor.visible=false;actor.body_collider.collision_layer=0;actor.get_node("Vitality").hit_body.collision_layer=0
 var record:Dictionary={"actor":actor,"job":job,"pending":0.0,"distance":0.0,"direction":1,"travelled":0.0,"unload":0.0}
 records.append(record);apply_saved(record)
 if remote_visuals:
  actor.set_process(false);actor.animation_tree.active=false

func update_work(record:Dictionary,delta:float) -> void:
 var actor:Node3D=record.actor
 var job:String=record.job
 actor.perform("repair" if job in ["gun_cleaner","cook"] else "read",delta,job=="drinking_partner" and fposmod(elapsed,8.0)>4.0)
 actor.set_meta("camp_job",job)
 if job=="gun_cleaner":
  var gun:Node3D=actor.get_node_or_null("RebelEnfield")
  if gun!=null:
   gun.position=Vector3(-.48,.72,.28);gun.rotation=Vector3.ZERO;gun.scale=Vector3.ONE*.72
   actor.solve_hand_contact("l",actor.to_global(Vector3(.2,.76,.3)))
   actor.solve_hand_contact("r",actor.to_global(Vector3(-.1+.16*sin(elapsed*2),.77,.3)))
 elif job=="cook":
  var hand:Vector3=actor.to_global(Vector3(.12+.06*sin(elapsed*2),.65,.60+.04*cos(elapsed*2)))
  actor.solve_hand_contact("r",hand);actor.set_grip("r",.5)
  var tip:Vector3=actor.get_meta("cooking_surface").global_position+Vector3(.06*sin(elapsed*2),.02,.04*cos(elapsed*2))
  var tool:Node3D=actor.get_meta("cooking_tool")
  tool.global_position=hand.lerp(tip,.5);tool.look_at(tip)
  tool.scale.z=hand.distance_to(tip)/.65
 elif job=="drinker":
  var sip:float=smoothstep(.0,.6,maxf(0.0,sin(elapsed*.65)))
  var target:Vector3=actor.to_global(Vector3(-.17,lerpf(.66,1.31,sip),lerpf(.32,.16,sip)))
  actor.solve_hand_contact("r",target)
  var cup:Node3D=actor.get_meta("work_prop");cup.global_position=target
  cup.rotation.x=-.35*sip
  var other:Node3D=get_node_or_null("Camp_drinking_partner")
  if other!=null:actor.rotation.y=atan2(other.position.x-actor.position.x,other.position.z-actor.position.z)
 elif job=="drinking_partner":
  var other:Node3D=get_node_or_null("Camp_drinker")
  if other!=null:actor.rotation.y=atan2(other.position.x-actor.position.x,other.position.z-actor.position.z)
 actor.finish_contacts()

func advance_carrier(record:Dictionary,delta:float) -> void:
 var actor:Node3D=record.actor
 var distance:float=record.distance;var direction:int=record.direction
 var load:Node3D=actor.get_meta("carried_load")
 var delivered:Node3D=actor.get_meta("delivered_load")
 if record.unload>0.0:
  record.unload=maxf(0.0,record.unload-delta)
  actor.travel_speed=0;actor._set_animation(&"idle",delta)
  var reach:float=sin((1.0-record.unload/2.0)*PI)
  for side in ["l","r"]:
   actor.solve_hand_contact(side,load.to_global(Vector3(.255 if side=="l" else -.255,-reach*.025,-.195+reach*.02)))
  if record.unload<1.0:load.visible=false;delivered.visible=true
  return
 load.visible=direction>0
 var motion:=Vector3(0,0,direction*.7*delta)
 var blocked:bool=carrier_blocked(actor,motion)
 if not blocked:
  actor.position+=motion;distance+=direction*.7*delta;record.travelled+=motion.length()
 if distance>=2.5 or distance<=0.0:
  if distance>=2.5 and direction>0:record.unload=2.0
  if distance<=0.0:delivered.visible=false
  distance=clampf(distance,0.0,2.5);direction=-direction
 record.distance=distance;record.direction=direction
 actor.rotation.y=rotate_toward(actor.rotation.y,0.0 if direction>0 else PI,delta*3.0)
 actor.travel_speed=0.0 if blocked else .7;actor.walk_direction=float(direction);actor._set_animation(&"idle" if blocked else &"walk",delta)
 if not load.visible:return
 for side in ["l","r"]:
  var target:Vector3=load.to_global(Vector3(.255 if side=="l" else -.255,.0,-.195))
  actor.set_meta("camp_grip_target_"+side,target)
  actor.solve_hand_contact(side,target);actor.set_grip(side,.6)
 actor.body_collider.force_update_transform()

func carrier_blocked(actor:Node3D,motion:Vector3) -> bool:
 if actor._patrol_body_blocked(motion):return true
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=sweep_shape;query.collision_mask=1;query.exclude=[actor.body_collider.get_rid()]
 # Lift the probe's bottom above its support so the floor is not an obstacle.
 query.transform=actor.global_transform;query.transform.origin+=Vector3.UP*.85
 query.motion=global_basis*motion;query.margin=.002
 var hits:PackedFloat32Array=actor.get_world_3d().direct_space_state.cast_motion(query)
 return hits.size()>=2 and hits[0]<.999

func export_state() -> Dictionary:
 var output:Dictionary=saved_roles.duplicate(true)
 output["_routine_clock"]=routine_clock
 for record in records:
  var actor:Node3D=record.actor;var vitality:Node=actor.get_node("Vitality")
  output[record.job]={"distance":record.distance,"direction":record.direction,"unload":record.unload,"health":vitality.health,"dead":vitality.dead,"knocked_out":actor.get_meta("knocked_out",false)}
 return output
func restore_state(data:Dictionary) -> void:
 saved_roles=data.duplicate(true)
 routine_clock=maxf(0.0,float(data.get("_routine_clock",0.0)))
 for record in records:apply_saved(record)
func apply_saved(record:Dictionary) -> void:
 var state:Variant=saved_roles.get(record.job,{})
 if not state is Dictionary:return
 record.distance=clampf(float(state.get("distance",0.0)),0.0,2.5)
 record.unload=clampf(float(state.get("unload",0.0)),0.0,2.0)
 record.direction=1 if int(state.get("direction",1))>=0 else -1
 var actor:Node3D=record.actor;var vitality:Node=actor.get_node("Vitality")
 vitality.health=clampf(float(state.get("health",75.0)),0.0,75.0)
 vitality.dead=bool(state.get("dead",false))
 var knocked_out:bool=bool(state.get("knocked_out",false)) and not vitality.dead
 actor.set_meta("dead",vitality.dead);actor.set_meta("knocked_out",knocked_out)
 var alive:bool=not vitality.dead and not knocked_out
 actor.body_collider.collision_layer=1 if actor.visible and alive else 0
 vitality.hit_body.collision_layer=8 if actor.visible and alive else 0
 actor.body_collider.get_node("BodyShape").set_deferred("disabled",not alive)
 if record.job=="carry_supplies":
  actor.position.z=20.0+record.distance
  actor.get_meta("carried_load").visible=record.direction>0 or record.unload>=1.0
  actor.get_meta("delivered_load").visible=record.direction<0 and record.unload<1.0

func update_mangal_seat(wants:bool) -> void:
 var mangal:Node3D=sites.mangal
 mangal.set_meta("hideout_discussing",wants)
 if wants and not is_instance_valid(mangal.riding_socket):
  mangal.riding_cart=mangal_seat.get_parent();mangal.riding_socket=mangal_seat;mangal.driving=false;seat_owned=true
 elif wants and mangal.riding_socket!=mangal_seat:
  seat_owned=false
 elif not wants and seat_owned:
  if mangal.riding_socket==mangal_seat:
   mangal.riding_socket=null;mangal.riding_cart=null;mangal.foot_plant.clear()
   if mangal.global_position.distance_to(mangal_seat.global_position)<1.8:mangal.global_position.y=to_global(Vector3(0,.2,0)).y
  seat_owned=false

func _exit_tree() -> void:
 if seat_owned and is_instance_valid(sites) and is_instance_valid(sites.mangal):
  sites.mangal.set_meta("hideout_discussing",false)
  if sites.mangal.riding_socket==mangal_seat:sites.mangal.riding_socket=null;sites.mangal.riding_cart=null
