extends RefCounted
## Visual evidence only: the restrained target cannot identify/report this action.
static func witnesses(attacker: CharacterBody3D, victim: Node3D) -> Array[String]:
 var result:Array[String]=[]
 for observer in attacker.get_tree().get_nodes_in_group("combat_actors"):
  if observer==victim or not observer is Node3D:continue
  if observer.get_meta("combat_faction","") not in ["british","police"]:continue
  if observer.get_meta("grappled",false):continue
  if preload("res://systems/visual_perception.gd").sees(observer,attacker):result.append(str(observer.get_path()))
 return result
static func report(attacker: CharacterBody3D, victim: Node3D) -> bool:
 var seen:=witnesses(attacker,victim)
 if seen.is_empty():return false
 for authority in attacker.get_tree().get_nodes_in_group("police_crime_observers"):
  if authority.has_method("record_incident"):
   authority.record_incident("takedown",victim.global_position,seen,2)
  elif authority.has_method("report_crime"):
   authority.report_crime(attacker,"assault",victim.global_position)
 return true
