extends Node
## Owns only the authentic mission rear seat. Normal orbit input stays active.
var director:Node
var active=false
var last_heading=0.0
var last_stage=""
var establish_age=0.0
var previous_pitch=0.0
var excluded:Array[RID]=[]
var old_queries:Array=[]
var battle_armed=false
func _ready() -> void:
 director=get_parent();process_priority=90
func _process(delta:float) -> void:
 if not director.configured:return
 var player:CharacterBody3D=director.player;var cart:Node3D=director.cart
 var seated:bool=director.stage in ["outbound","loading","chase"] and cart.rider==player and cart.boarding.seat_name=="ConsignmentRearSeat" and cart.boarding.transition.is_empty()
 if not seated:
  if active:release()
  return
 var arm:SpringArm3D=player.get_node("CameraPivot/SpringArm3D")
 var camera:Node=arm.get_node("Camera3D")
 if not active:
  active=true;last_heading=cart.global_rotation.y;previous_pitch=player.camera_pitch
  player.set_meta("consignment_camera",true)
  old_queries=[camera.clearance_query.exclude.duplicate(),camera.shoulder_query.exclude.duplicate(),camera.shoulder_overlap.exclude.duplicate()]
  excluded.clear()
  for body in cart.find_children("*","CollisionObject3D",true,false):
   var rid:RID=body.get_rid();excluded.append(rid);arm.add_excluded_object(rid)
  camera.clearance_query.exclude=old_queries[0]+excluded;camera.shoulder_query.exclude=old_queries[1]+excluded;camera.shoulder_overlap.exclude=old_queries[2]+excluded
  var aim_excluded:Array[RID]=excluded.duplicate()
  for escort in [director.driver,director.companion]:
   for body in escort.find_children("*","CollisionObject3D",true,false):aim_excluded.append(body.get_rid())
  player.set_meta("consignment_camera_exclusions",aim_excluded)
  camera.visible_distance=-1.0;last_stage=""
 player.set_meta("consignment_camera_chase",director.stage=="chase")
 player.set_meta("consignment_camera_pivot_height",cart.seat_sockets.ConsignmentRearSeat.global_position.y-player.global_position.y+.84)
 var heading:float=cart.global_rotation.y
 player.camera_pivot.rotation.y+=angle_difference(last_heading,heading);last_heading=heading
 if last_stage!=director.stage:
  last_stage=director.stage;establish_age=.65;battle_armed=false
 if establish_age>0:
  establish_age=maxf(0,establish_age-delta)
  var target:float=heading+(PI if director.stage=="chase" else .35)
  player.camera_pivot.global_rotation.y=lerp_angle(player.camera_pivot.global_rotation.y,target,1-exp(-7*delta))
  player.camera_pitch=lerpf(player.camera_pitch,-.12,1-exp(-7*delta));player.camera_pivot.rotation.x=player.camera_pitch
 if director.stage=="chase" and not battle_armed and preload("res://story/rear_passenger_combat.gd").fire_ready(player):
  battle_armed=true;var gear=player.get_node("VisualRoot/CharacterVisual").equipment;gear.stowed=false;gear._refresh()
 cart.seat_sockets.ConsignmentRearSeat.position.z=move_toward(cart.seat_sockets.ConsignmentRearSeat.position.z,3.45 if director.stage=="chase" else 2.9,delta*.85)
func release() -> void:
 var player:Node=director.player;var arm:SpringArm3D=player.get_node("CameraPivot/SpringArm3D");var camera:Node=arm.get_node("Camera3D")
 player.set_meta("consignment_camera",false);player.set_meta("consignment_camera_chase",false);player.remove_meta("consignment_camera_exclusions")
 for rid in excluded:arm.remove_excluded_object(rid)
 if old_queries.size()==3:
  camera.clearance_query.exclude=old_queries[0];camera.shoulder_query.exclude=old_queries[1];camera.shoulder_overlap.exclude=old_queries[2]
 excluded.clear();old_queries.clear();active=false;last_stage="";camera.visible_distance=-1.0
func _exit_tree() -> void:
 if active and is_instance_valid(director.player):release()
