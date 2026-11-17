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
var foot_extension=0.0
var rear_view:Camera3D
var transition_view:Camera3D
var transition_previous:Camera3D
var old_visual_priority=0
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
  old_visual_priority=player.get_node("VisualRoot/CharacterVisual").process_priority
  player.get_node("VisualRoot/CharacterVisual").process_priority=100
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
  last_stage=director.stage;establish_age=.65;battle_armed=false;foot_extension=0.0
 if establish_age>0:
  establish_age=maxf(0,establish_age-delta)
  var target:float=heading+(PI if director.stage=="chase" else .35)
  player.camera_pivot.global_rotation.y=lerp_angle(player.camera_pivot.global_rotation.y,target,1-exp(-7*delta))
  player.camera_pitch=lerpf(player.camera_pitch,-.12,1-exp(-7*delta));player.camera_pivot.rotation.x=player.camera_pitch
 if director.stage=="chase" and establish_age<=0:
  # Orbit stays inside the physical firing aperture. Excluding our own wagon
  # from virtual camera probes must not let the eye pass through its canvas.
  var offset:float=angle_difference(heading+PI,player.camera_pivot.global_rotation.y)
  player.camera_pivot.global_rotation.y=heading+PI+clampf(offset,-.45,.45)
  player.camera_pitch=clampf(player.camera_pitch,-.30,.20)
  player.camera_pivot.rotation.x=player.camera_pitch
 if is_instance_valid(rear_view) and rear_view.is_queued_for_deletion():rear_view=null
 if director.stage=="chase" and not battle_armed and not is_instance_valid(rear_view) and not is_instance_valid(transition_view):
  # Keep the brief concealment-to-fire transition outside the canvas and cargo.
  transition_previous=get_viewport().get_camera_3d()
  transition_view=Camera3D.new();transition_view.name="ConsignmentTransitionCamera";transition_view.fov=60;transition_view.near=.1
  cart.add_child(transition_view);transition_view.position=Vector3(0,3.05,7.0)
  transition_view.look_at(cart.to_global(Vector3(0,1.65,2.7)));transition_view.make_current()
 if director.stage=="chase" and not battle_armed and preload("res://story/rear_passenger_combat.gd").fire_ready(player):
  battle_armed=true;var gear=player.get_node("VisualRoot/CharacterVisual").equipment;gear.stowed=false;gear._refresh()
  if not is_instance_valid(rear_view):
   rear_view=preload("res://story/consignment_rear_view.gd").new();rear_view.player=player;cart.add_child(rear_view)
   if is_instance_valid(transition_previous):rear_view.previous=transition_previous
  else:rear_view.make_current()
  if is_instance_valid(transition_view):transition_view.queue_free();transition_view=null
 cart.seat_sockets.ConsignmentRearSeat.position.z=move_toward(cart.seat_sockets.ConsignmentRearSeat.position.z,3.60 if director.stage=="chase" else 2.9,delta*.85)
 foot_extension=move_toward(foot_extension,1.0 if director.stage=="chase" and cart.seat_sockets.ConsignmentRearSeat.position.z>3.59 else 0.0,delta*2)
 player.set_meta("consignment_foot_extension",foot_extension)
func release() -> void:
 if is_instance_valid(rear_view):rear_view.release();rear_view=null
 if is_instance_valid(transition_view):
  if transition_view.current and is_instance_valid(transition_previous):transition_previous.make_current()
  transition_view.queue_free();transition_view=null
 transition_previous=null
 var player:Node=director.player
 # A restore may have replaced a camera before the previous one retired.
 if player.has_meta("consignment_fpv_camera"):
  var owned=player.get_meta("consignment_fpv_camera")
  if is_instance_valid(owned) and not owned.is_queued_for_deletion() and owned.get_parent()==director.cart:owned.release()
  if player.has_meta("consignment_fpv_camera"):player.remove_meta("consignment_fpv_camera")
 if player.has_meta("consignment_aim_uv"):player.remove_meta("consignment_aim_uv")
 var arm:SpringArm3D=player.get_node("CameraPivot/SpringArm3D");var camera:Node=arm.get_node("Camera3D")
 player.get_node("VisualRoot/CharacterVisual").process_priority=old_visual_priority
 player.set_meta("consignment_camera",false);player.set_meta("consignment_camera_chase",false);player.remove_meta("consignment_camera_exclusions")
 for rid in excluded:arm.remove_excluded_object(rid)
 if old_queries.size()==3:
  camera.clearance_query.exclude=old_queries[0];camera.shoulder_query.exclude=old_queries[1];camera.shoulder_overlap.exclude=old_queries[2]
 excluded.clear();old_queries.clear();active=false;last_stage="";camera.visible_distance=-1.0
func _exit_tree() -> void:
 if active and is_instance_valid(director.player):release()
