extends "res://combat/climbing_firearm_attack.gd"
## Mounted officers use the Adams pistol; the actor invokes this after its riding pose.
const GRIP := Vector3(-.126,-.015,0)
const MUZZLE := Vector3(.17,0,.064)
const PISTOL_SCALE := .72
const CAPACITY := 5
var chambered := CAPACITY
var reloading := false

func _ready() -> void:
 process_priority=60
 gun=preload("res://environment/weapons/adams_1851/adams_1851.glb").instantiate()
 gun.name="MountedAdamsPistol";add_child(gun)
 sound=AudioStreamPlayer3D.new();sound.stream=preload("res://audio/weapons/adams_shot.wav");sound.max_distance=180;sound.volume_db=-12;add_child(sound)

func _process(delta:float) -> void:
 cooldown=maxf(0.0,cooldown-delta);recoil=move_toward(recoil,0.0,delta*.4)
 if owner_actor.get_meta("dead",false) or owner_actor.get_meta("knocked_out",false) or owner_actor.get_meta("grappled",false) or owner_actor.get_meta("combat_action","")=="hit":
  aim_age=0.0;return
 if reloading and cooldown<=0.0:
  chambered=mini(CAPACITY,cartridges);reloading=false
 var aiming:=can_engage()
 var grip:Vector3=owner_actor.to_global(Vector3(-.16,1.35,.13))
 var forward:Vector3=(target_point()-grip).normalized() if aiming else owner_actor.global_basis.z
 var reload_blend:=0.0
 if reloading:
  var progress:float=1.0-cooldown/reload_seconds
  reload_blend=Loading.phase_ease(progress,0.0,.18)*(1.0-Loading.phase_ease(progress,.82,1.0))
  grip=grip.lerp(owner_actor.to_global(Vector3(-.14,.98,.25)),reload_blend)
  forward=forward.lerp((Vector3.UP+owner_actor.global_basis.z*.35).normalized(),reload_blend).normalized()
 var side:=forward.cross(Vector3.UP).normalized()
 if side.length_squared()<.1:side=owner_actor.global_basis.x
 var basis:=Basis(forward,side.cross(forward).normalized(),side)
 gun.global_transform=Transform3D(basis.scaled(Vector3.ONE*PISTOL_SCALE),grip-forward*recoil-basis*(GRIP*PISTOL_SCALE))
 if owner_actor.has_method("solve_hand_contact"):
  owner_actor.solve_hand_contact("r",gun.to_global(GRIP))
  owner_actor.solve_hand_contact("l",gun.to_global(Vector3(-.04,.02,.03)) if reloading else owner_actor.to_global(Vector3(.18,1.0,.12)))
  owner_actor.set_grip("r",.4);owner_actor.set_grip("l",.6 if reloading else .2)
 if not aiming or cartridges<=0 or cooldown>0.0 or reloading:
  aim_age=0.0;return
 var excluded:Array[RID]=[owner_actor.body_collider.get_rid()]
 for rid in owner_actor.get_meta("firearm_exclusions",[]):
  if typeof(rid)==TYPE_RID:excluded.append(rid)
 var muzzle:=gun.to_global(MUZZLE);var space:=get_world_3d().direct_space_state
 if not Trace.sight(space,get_tree(),grip,muzzle,excluded).is_empty():aim_age=0.0;return
 var sight:=Trace.sight(space,get_tree(),muzzle,target_point(),excluded)
 if sight.is_empty() or sight.collider!=target:aim_age=0.0;return
 aim_age+=delta
 if aim_age>=aim_delay:
  cartridges-=1;chambered-=1;shots+=1;recoil=.055;aim_age=0.0
  if chambered<=0 and cartridges>0:reloading=true;cooldown=reload_seconds
  else:cooldown=.65
  sound.play();Trace.shoot(space,get_tree(),muzzle,target_point()+forward*.5,shot_damage,excluded,owner_actor)

func can_engage() -> bool:
 return hostile and is_instance_valid(target) and target.health>0 and target.get_meta("consignment_rear_combat",false) and owner_actor.global_position.distance_to(target.global_position)<45
func turn_owner_to_target() -> bool:
 return false
func target_point() -> Vector3:
 return target.global_position+Vector3.UP*.55
