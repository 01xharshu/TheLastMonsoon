extends RefCounted
## Offline body-derived seam bindings. Never read GPU mesh arrays at runtime.
const Profiles=preload("res://characters/npcs/households/waist_profiles.tres")
static func anchors(actor:Node3D,_rig:Skeleton3D,sides:int) -> Array[Vector3]:
 var key:String=actor.get_meta("drape_profile","")
 if key.is_empty():key="official_woman" if actor.get("movement_profile")==&"female" else ("landowner" if "landowner" in actor.name.to_lower() else "merchant")
 var profiles:Dictionary=Profiles.get_meta("profiles")
 var result:Array[Vector3]=[]
 if not profiles.has(key):push_error("No body-derived waist profile: "+key);return result
 var profile:Dictionary=profiles[key]
 if profile.bindings.size()!=sides:push_error("Waist binding segment mismatch");return result
 for binding in profile.bindings:result.append(Vector3(binding[0],binding[1],binding[2]))
 actor.set_meta("waist_fit_samples",int(profile.body_samples))
 return result
