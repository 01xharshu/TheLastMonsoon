extends Node
## Existing MPFB soldier, existing queued capsule navigation and animation owner.
var actor: Node3D
var encounters: Node3D
var viewer: Node3D
var points:=PackedVector3Array()
var duty := "guard_round"
var inquiry: Node
var index := 1
var wait := 0.0
var elapsed := 0.0
var walked := 0.0
var navigation: Dictionary={}
func _ready() -> void:
 actor=get_parent();navigation={"actor":actor};add_to_group("military_duties")
 var world:=preload("res://systems/world_context.gd").find_world(actor)
 if world==null:return
 encounters=world.get_node_or_null("CombatEncounters");viewer=world.get_node_or_null("Player")
 if inquiry==null:actor.set_meta("external_combat_motion",true)
 elif duty=="station_sentry" and points.size()>=2 and is_instance_valid(inquiry.station):
  # The former forward goal ran directly into the entrance column. Walk
  # outward along the frontage, away from the entrance and its companion.
  var local:Vector3=inquiry.station.to_local(points[0])
  var outward:float=-1.0 if local.x<0 else 1.0
  points[1]=inquiry.station.to_global(local+Vector3(outward*3.0,0,0))
 actor.set_meta("daily_activity",duty)
func _physics_process(delta: float) -> void:
 if is_instance_valid(inquiry):
  var director:Node=inquiry.world.get_node_or_null("DevStory")
  if inquiry.stage!="released" or not inquiry.second_return_path.is_empty() or (director!=null and director.active) or (is_instance_valid(viewer) and viewer.get_meta("story_cinematic",false)) or actor.get_meta("police_engaged",false) or actor.get_meta("external_combat_motion",false) or actor.get("duty_state") not in ["guard","idle"]:
   elapsed=0;return
 if not is_instance_valid(encounters):
  var world:=preload("res://systems/world_context.gd").find_world(actor)
  if world!=null:
   encounters=world.get_node_or_null("CombatEncounters")
   viewer=world.get_node_or_null("Player")
 if not is_instance_valid(encounters) or points.size()<2:return
 # Recruitment keeps movement disabled until physical return to the old duty.
 if (inquiry==null and not actor.movement_enabled) or actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false) or actor.get_meta("city_custody",false) or actor.get_meta("combat_action","")!="" or actor.get_meta("defending",false):
  elapsed=0;return
 elapsed+=delta
 if elapsed<preload("res://systems/simulation_budget.gd").interval(actor,viewer):return
 var step:=elapsed;elapsed=0
 if wait>0:
  wait=maxf(0,wait-step);actor.travel_speed=0;return
 var before:=actor.global_position
 if encounters.navigate_patrol(navigation,points[index],1.1,step):
  index=(index+1)%points.size();wait=4.0+float(actor.get_instance_id()%7)
 walked+=before.distance_to(actor.global_position)
 actor.set_meta("daily_activity",duty if wait>0 else "walking_"+duty)
