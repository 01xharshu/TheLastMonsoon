extends RefCounted
## Stable actor-relative coverage. Never choose an unrelated world-space angle.
static func eye(actor: Node3D) -> Vector3:
 var rig: Skeleton3D
 if actor is CharacterBody3D:
  var visual=actor.get_node_or_null("VisualRoot/CharacterVisual")
  if visual!=null:rig=visual.skeleton
 elif "_skeleton" in actor:rig=actor._skeleton
 if rig!=null:
  var head: int=rig.find_bone("head")
  if head>=0:return rig.to_global(rig.get_bone_global_pose(head).origin)+Vector3.UP*.08
 return actor.global_position+Vector3.UP*1.5

static func shot(arjun: Node3D,partner: Node3D,arjun_speaking: bool,pov: bool) -> Dictionary:
 var hero_eye: Vector3=eye(arjun);var other_eye: Vector3=eye(partner)
 pov=pov and hero_eye.distance_to(other_eye)>=1.25
 var axis: Vector3=other_eye-hero_eye;axis.y=0
 if axis.length_squared()<.01:axis=Vector3.FORWARD
 axis=axis.normalized()
 var side: Vector3=axis.cross(Vector3.UP).normalized()
 var focus: Vector3=hero_eye if arjun_speaking else other_eye
 # Keep the camera on one side of the axis; POV begins in front of Arjun's face.
 var at: Vector3=hero_eye+axis*.22 if pov and not arjun_speaking else hero_eye+axis*.95+side*.65 if arjun_speaking else hero_eye-axis*.55+side*.65+Vector3.UP*.08
 return {"position":at,"target":focus,"pov":pov and not arjun_speaking}
