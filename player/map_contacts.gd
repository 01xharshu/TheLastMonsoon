extends RefCounted
## One world-scoped registry shared by radar and paused map.
const NORMAL := Color(.58,.59,.59,1)
const HOSTILE := Color(.9,.10,.07,1)
var actors: Array[WeakRef]=[]
var refresh_at := -1
func sample(player: Node3D) -> Array[Dictionary]:
 var now:=Time.get_ticks_msec()
 if now>=refresh_at:
  refresh_at=now+500;actors.clear()
  for actor in player.get_tree().get_nodes_in_group("combat_actors"):
   if actor is Node3D:actors.append(weakref(actor))
 var records: Array[Dictionary]=[]
 var world:=player.get_parent()
 var coordinator:=world.get_node_or_null("Settlement/DistrictPolice/ThanaStaff/ArrestCoordinator")
 for reference in actors:
  var actor: Node3D=reference.get_ref()
  if not is_instance_valid(actor) or actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):continue
  var hostile: bool=actor.get_meta("police_engaged",false)
  var defence:=actor.get_node_or_null("SelfDefence")
  if defence!=null:hostile=hostile or (defence.active and defence.provoked and not defence.returning and defence.opponent==player)
  if coordinator!=null:hostile=hostile or (coordinator.officer==actor and coordinator.phase in ["approach","fight","restraint","escort"])
  records.append({"position":Vector2(actor.global_position.x,actor.global_position.z),"color":HOSTILE if hostile else NORMAL})
 return records
