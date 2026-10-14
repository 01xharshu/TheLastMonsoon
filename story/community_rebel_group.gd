extends Node
## One bounded local protection group. Recruitment needs trust and witnessed violence.
const Sight = preload("res://systems/visual_perception.gd")
const Nav = preload("res://story/community_navigation.gd")
var mission: Node
var trusted := false
var responders: Array[int] = []
var members: Array[Node3D] = []
var navigation: Array[Node] = []
var homes: Array[Vector3] = []
var ages: Array[float] = []
var hits: Array[bool] = []
func configure(owner_node: Node) -> void:
 mission = owner_node
 for i in 3:
  var source := "res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb" if i != 1 else "res://characters/npcs/households/merchant.glb"
  var member: Node3D = mission.person("VillageProtector%d"%i,source,[Vector3(-3,0,17),Vector3(3,0,17),Vector3(2,0,19)][i],"indian",float(i)*.73)
  members.append(member)
  homes.append(member.global_position)
  ages.append(0.0)
  hits.append(false)
  var motion: Node = Nav.new()
  add_child(motion)
  motion.configure(member,mission.encounters)
  navigation.append(motion)
  await get_tree().process_frame
func witness_attack(attacker: Node3D) -> void:
 if not trusted or attacker != mission.enforcer or mission.defeated(attacker): return
 for i in members.size():
  if i in responders or mission.defeated(members[i]): continue
  if not Sight.sees(members[i],mission.player,28): continue
  var ray := PhysicsRayQueryParameters3D.create(members[i].global_position+Vector3.UP*1.4,attacker.global_position+Vector3.UP*1.2,1)
  ray.exclude = [members[i].body_collider.get_rid(),attacker.body_collider.get_rid()]
  if members[i].get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): responders.append(i)
func tick(delta: float) -> void:
 for i in members.size():
  var member: Node3D = members[i]
  if mission.defeated(member) or member.get_meta("grappled",false):
   navigation[i].cancel()
   continue
  if i not in responders: continue
  if mission.stage != "rescue" or mission.defeated(mission.enforcer):
   if navigation[i].advance(homes[i],1.1,delta): responders.erase(i)
   continue
  var target: Node3D = mission.enforcer
  var toward := target.global_position-member.global_position
  if toward.length()>.9:
   navigation[i].advance(target.global_position-toward.normalized()*.65,1.65,delta,.10)
   ages[i]=0.0
   continue
  navigation[i].cancel()
  member.global_rotation.y=atan2(toward.x,toward.z)
  if member.get_meta("combat_action","")=="hit": continue
  ages[i]+=delta
  if ages[i]>=1.4:
   ages[i]=0.0
   hits[i]=false
   member.combat_react("strike")
  if ages[i]>=.28 and ages[i]<=.60 and not hits[i] and mission.encounters.strike_hits_actor(member,target):
   hits[i]=true
   target.get_node("Vitality").receive_hit(8,member,"punch")
func export_state() -> Dictionary:
 var people: Array[Dictionary] = []
 for member in members: people.append(mission.person_state(member))
 return {"trusted":trusted,"responders":responders.duplicate(),"members":people}
func restore_state(data: Dictionary) -> void:
 trusted=bool(data.get("trusted",false))
 responders.clear()
 if trusted:
  for value in data.get("responders",[]):
   var index:=int(value)
   if index>=0 and index<members.size() and index not in responders: responders.append(index)
 var people: Array = data.get("members",[])
 for i in members.size():
  navigation[i].cancel()
  ages[i]=0
  hits[i]=false
  if i<people.size() and people[i] is Dictionary: mission.restore_person(members[i],people[i])
  else: mission.restore_person(members[i],{})
func reset() -> void:
 responders.clear()
 for i in members.size():
  var at: Vector3 = homes[i]
  mission.restore_person(members[i],{"position":[at.x,at.y,at.z]})
  navigation[i].cancel()
