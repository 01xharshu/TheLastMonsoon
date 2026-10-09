extends Node
## Different discussion phases; distant conversations stop updating hands.
var person: Node3D
var offset:=0.0
var age:=0.0
var viewer: Node3D
var seated:=false
var ground_y:=0.0
func _process(delta: float) -> void:
 if person==null or person.get_meta("dead",false) or person.get_meta("knocked_out",false):return
 if viewer==null:viewer=get_tree().root.find_child("Player",true,false)
 if viewer==null or viewer.global_position.distance_squared_to(person.global_position)>900:return
 age+=delta
 if seated:
  person.global_position.y=ground_y-.48
  for side in ["l","r"]:
   for pair in [["thigh_",-1.35],["calf_",1.5],["foot_",-.15]]:
    var label: String=pair[0]+side
    person._skeleton.set_bone_pose_rotation(person._bones[label],person._base_rotations[label]*Quaternion(person._pitch_axes[label],pair[1]))
  for side in ["l","r"]:
   var ankle: Vector3=person.to_global(Vector3(.17 if side=="l" else -.17,.55,.45));ankle.y=ground_y+.07
   person.foot_plant._solve(person.foot_plant.legs[side],person._skeleton.to_local(ankle))
  var collision: CollisionShape3D=person.body_collider.get_node("BodyShape")
  collision.shape.height=1.1;collision.position.y=.8
 if fmod(age+offset,8)<3:
  person.solve_hand_contact("r",person.to_global(Vector3(-.23,1.05,.25))+Vector3.UP*sin(age*2+offset)*.035)
  person.set_grip("r",.1)
