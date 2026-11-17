extends RefCounted
## Deterministic shade avenues on open verges, built once with shared tree LODs.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Variety = preload("res://world/suryagarh/tree_variety.gd")
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
const Startup = preload("res://systems/world_startup.gd")
const SPACING := 12.5
const OFFSET := 11.0
const LIMIT := 400
const ROUTES := ["government_house_road", "east_bridge", "police_to_compound", "cantonment_approach", "port_lower_service_road", "port_lower_service_branch", "port_approach"]

static func candidates(layout: RefCounted) -> Array[Vector2]:
 var paths: Array = []
 # The original north/south trunk has a surveyed replacement through the uplands.
 for interval in [Vector2(-690,360),Vector2(510,710)]:
  var path: Array[Vector2] = []
  for z in range(int(interval.x),int(interval.y)+1,12):path.append(Vector2(layout.road_x(z),z))
  paths.append(path)
 for name in ROUTES:paths.append(Layout.ROUTES[name])
 var result: Array[Vector2] = []
 for path in paths:
  var walked := 0.0
  var next := 16.0
  for i in range(path.size()-1):
   var a: Vector2 = path[i];var b: Vector2 = path[i+1]
   var length := a.distance_to(b)
   var direction := (b-a).normalized()
   var side := Vector2(-direction.y,direction.x)
   while next < walked+length:
    var center := a+direction*(next-walked)
    for sign in [-1.0,1.0]:
     var p: Vector2 = center+side*sign*(OFFSET+sin(next*.071)*1.1)
     if suitable(layout,p):
      var separated := true
      for prior in result:
       if p.distance_squared_to(prior)<12.0*12.0:separated=false;break
      if separated:result.append(p)
    next+=SPACING
   walked+=length
 return result

static func suitable(layout: RefCounted,p: Vector2) -> bool:
 if layout.road_distance(p.x,p.y)<8.5:return false
 if layout.plot_clearance(p.x,p.y)<12.0:return false
 if absf(p.x-layout.river_x(p.y))<layout.river_width(p.y)+18:return false
 if layout.height(p.x,p.y)<1.5 or p.y>770:return false
 if layout.normal(p.x,p.y).y<.95:return false
 if Ground.consignment_road_reserved(p):return false
 return true

static func install(world: Node3D) -> int:
 if world.has_node("RoadsideShadeTrees"):return 0
 var holder := Node3D.new();holder.name="RoadsideShadeTrees";world.add_child(holder)
 var layout := Layout.new()
 var space := world.get_world_3d().direct_space_state
 var ray := PhysicsRayQueryParameters3D.new();ray.collision_mask=Ground.TERRAIN_SUPPORT_LAYER
 var probe := PhysicsShapeQueryParameters3D.new()
 var sphere := SphereShape3D.new();sphere.radius=5.0;probe.shape=sphere
 probe.collision_mask=1;probe.exclude=Ground.terrain_exclusions(world)
 var groups: Dictionary = {};var accepted: Array[Vector3] = []
 for p in candidates(layout):
  if accepted.size()>=LIMIT:break
  if accepted.size()%16==0:await Startup.checkpoint(world,"Growing roadside shade…")
  var y: float=layout.height(p.x,p.y)
  ray.from=Vector3(p.x,y+40,p.y);ray.to=Vector3(p.x,y-40,p.y)
  var hit := space.intersect_ray(ray)
  if hit.is_empty() or hit.normal.y<.95:continue
  var root: Vector3=hit.position
  probe.transform=Transform3D(Basis.IDENTITY,root+Vector3.UP*3.0)
  if not space.intersect_shape(probe,1).is_empty():continue
  var index := accepted.size()
  # Stable location-based variation keeps the mix independent of rejected sites.
  var selector := posmod(int(floor(p.x * 13.0)) * 31 + int(floor(p.y * 17.0)) * 17, 10)
  var kind: String="peepal" if selector<3 else "mango" if selector<6 else "spreading" if selector<9 else "palm"
  var mesh: Mesh=Variety.mesh_for(kind)
  var profile := Variety.profile_for(mesh)
  if profile.is_empty():continue
  var base: Vector3=profile[0].centre-Vector3.UP*float(profile[0].height)*.5
  var scale := (11.0+float(index%5)*.65)/mesh.get_aabb().size.y
  var basis := Basis(Vector3.UP,fmod(p.x*.73+p.y*.39,TAU)).scaled(Vector3.ONE*scale)
  var at := Transform3D(basis,root-Vector3.UP*.12-basis*base)
  var tile := Vector2i(floori(p.x/72),floori(p.y/72))
  var key := str(tile)+kind
  if not groups.has(key):groups[key]={"tile":tile,"kind":kind,"mesh":mesh,"profile":profile,"trees":[]}
  groups[key].trees.append(at);accepted.append(root)
 var bodies: Dictionary={};var shape_cache: Dictionary={}
 for group in groups.values():
  var tile: Vector2i=group.tile
  if not bodies.has(tile):
   var body := StaticBody3D.new();body.name="Trunks_%d_%d"%[tile.x,tile.y];body.set_meta("tree_trunk_geometry",true);holder.add_child(body);bodies[tile]=body
  var body: StaticBody3D=bodies[tile]
  var trees: Array[Transform3D]=[]
  for at in group.trees:trees.append(at)
  Variety.append_trunks(body,trees,group.profile,shape_cache)
  var center := Vector3(tile.x*72+36,0,tile.y*72+36)
  var mm := MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=group.mesh;mm.instance_count=trees.size()
  for index in trees.size():
   var at: Transform3D=trees[index];at.origin-=center;mm.set_instance_transform(index,at)
  var batch := MultiMeshInstance3D.new();batch.name="Shade_"+group.kind;batch.multimesh=mm;batch.position=center
  batch.visibility_range_end=460;batch.visibility_range_end_margin=40;batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  batch.lod_bias=.6;batch.set_meta("roadside_species",group.kind);holder.add_child(batch)
 holder.set_meta("roots",accepted);holder.set_meta("tree_count",accepted.size())
 print("ROADSIDE SHADE TREES ",accepted.size()," in ",bodies.size()," persistent trunk tiles")
 return accepted.size()
