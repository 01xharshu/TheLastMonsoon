extends Node
## Add restrained weight transfer to the current AnimationTree pose.
## The final stealth/contact layers retain authority over low stances and feet.
var visual:Node3D
var actor:CharacterBody3D
var previous_velocity:=Vector3.ZERO
var previous_heading:=0.0
var previous_position:=Vector3.ZERO
var lean:=Vector2.ZERO
var initialized:=false
func _ready()->void:
 visual=get_parent();actor=visual.actor;process_priority=18
func _process(delta:float)->void:
 if visual.skeleton==null:return
 var heading:float=actor.get_node("VisualRoot").global_rotation.y
 var discontinuity:bool=not initialized or delta>.12 or previous_position.distance_to(actor.global_position)>2
 var acceleration:=Vector3.ZERO;var turn:=0.0
 if not discontinuity:
  acceleration=actor.get_node("VisualRoot").global_basis.inverse()*(actor.velocity-previous_velocity)/maxf(delta,.001)
  turn=angle_difference(previous_heading,heading)/maxf(delta,.001)
 else:lean=Vector2.ZERO
 previous_velocity=actor.velocity;previous_heading=heading;previous_position=actor.global_position;initialized=true
 var active:bool=actor.is_physics_processing() and not actor.get_meta("story_cinematic",false) and actor.is_on_floor() and not actor.is_swimming and not (actor.has_meta("mounted_vehicle") and is_instance_valid(actor.get_meta("mounted_vehicle"))) and not actor.get_meta("climbing",false) and not actor.get_meta("paired_combat",false) and actor.get_meta("rest_action","")=="" and actor.get_meta("detention_action","")=="" and not actor.get_meta("opening_active",false)
 if visual.slash_phase>=0 or visual.knife_phase>=0 or visual.punch_phase>=0 or visual.kick_phase>=0 or visual.hit_phase>=0:active=false
 var low:float=actor.get_node("StealthStance").blend
 var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
 var target:=Vector2(clampf(-acceleration.z*.009,-.055,.075),clampf(-turn*speed*.004,-.055,.055)) if active else Vector2.ZERO
 target*=1.0-low
 lean=lean.lerp(target,1.0-exp(-10.0*minf(delta,.05)))
 if not active or lean.length()<.00001:return
 for record in [["spine_01",.65],["spine_02",.35],["head",-.4]]:
  var bone:String=record[0]
  if not visual.bones.has(bone):continue
  var axes:Basis=visual.axes[bone]
  var offset:=Quaternion(axes*Vector3.RIGHT,lean.x*record[1])*Quaternion(axes*Vector3.BACK,lean.y*record[1])
  var index:int=visual.bones[bone]
  visual.skeleton.set_bone_pose_rotation(index,visual.skeleton.get_bone_pose_rotation(index)*offset)
