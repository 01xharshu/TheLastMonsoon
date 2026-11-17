extends Node3D
## Small rural herds; no quest/cavalry/household replacement or modern pasture props.
signal built
const Grazer=preload("res://animals/field_grazer.gd")
const Terrain=preload("res://world/suryagarh/tree_trunk_collision.gd")
const Density=preload("res://world/suryagarh/settlements/countryside_density.gd")
const CENTERS=[Vector2(-690,185),Vector2(-690,285),Vector2(-600,365)]
var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var animals:Array[CharacterBody3D]=[]
var exclusions:Array[RID]=[]
var ready_for_grazing:=false
var height_cache:Dictionary={}
func _ready()->void:
 name="FieldGrazing";prepare.call_deferred()
func ground(at:Vector3)->float:
 var key:=Vector2i(roundi(at.x*10),roundi(at.z*10))
 if height_cache.has(key):return height_cache[key]
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(at.x,130,at.z),Vector3(at.x,-30,at.z),Terrain.TERRAIN_SUPPORT_LAYER)
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 var height:float=hit.position.y if not hit.is_empty() else layout.height(at.x,at.z)
 if height_cache.size()<8192:height_cache[key]=height
 return height
func land_allowed(p:Vector3)->bool:
 if layout.road_distance(p.x,p.z)<9 or Density.clearance(Vector2(p.x,p.z)):return false
 for lane in Density.lanes():
  for i in lane.size()-1:
   if layout.segment_distance(Vector2(p.x,p.z),lane[i],lane[i+1])<6:return false
 for z in [194,238,282,326]:
  if Rect2(Vector2(-657,z-20),Vector2(50,40)).has_point(Vector2(p.x,p.z)):return false
 var h:=ground(p)
 return absf(ground(p+Vector3.RIGHT)-h)<.17 and absf(ground(p+Vector3.FORWARD)-h)<.17
func allowed(p:Vector3,animal:CharacterBody3D=null)->bool:
 if not land_allowed(p):return false
 var q:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.8,1.8,3.6);q.shape=box
 q.transform.origin=Vector3(p.x,ground(p)+1.1,p.z);q.collision_mask=1
 var ignored:Array[RID]=exclusions.duplicate()
 if animal!=null:
  ignored.append(animal.get_rid())
  for body:CollisionObject3D in animal.find_children("*","CollisionObject3D",true,false):ignored.append(body.get_rid())
 q.exclude=ignored
 return get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()
func next_patch(animal:CharacterBody3D)->Vector3:
 for attempt in 20:
  var p:Vector3=animal.home+Vector3(animal.rng.randf_range(-7,7),0,animal.rng.randf_range(-7,7))
  p.y=ground(p)
  if allowed(p,animal):return p
 return animal.global_position
func prepare()->void:
 exclusions=Terrain.terrain_exclusions(get_parent())
 for herd in CENTERS.size():
  for slot in 3:
   var point:=Vector3(CENTERS[herd].x,0,CENTERS[herd].y)
   var found:=false
   for attempt in 64:
    point=Vector3(CENTERS[herd].x+float(attempt%8)*2-7,0,CENTERS[herd].y+float(attempt/8)*2-7)
    point.y=ground(point)
    if allowed(point):found=true;break
   if not found:push_warning("GRAZING pasture slot obstructed "+str(herd)+":"+str(slot));continue
   var animal:=Grazer.new();animal.kind="horse" if slot==2 else "bullock";animal.identity="field_%d_%d"%[herd,slot];animal.name="GrazingHorse" if slot==2 else "GrazingCow"
   animal.pasture=self;animal.position=point;animal.home=point;animal.goal=point;add_child(animal);animal.build();animals.append(animal)
   animal.rotation.y=float(herd+slot)*.73
   await get_tree().physics_frame
 ready_for_grazing=true;built.emit()
 print("FIELD GRAZING READY ",animals.size()," animals | stable draft/save identities")
