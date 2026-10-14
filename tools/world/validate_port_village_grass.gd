extends SceneTree
const Uplands=preload("res://world/suryagarh/port_village_uplands.gd")
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Grass=preload("res://world/suryagarh/grass_blades.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if DisplayServer.get_name()=="headless":
  push_error("Grass root validation requires native MultiMesh readback");quit(2);return
 var landscape:Node3D=load("res://world/suryagarh/generated/landscape.scn").instantiate();root.add_child(landscape)
 var bounds:=Uplands.BOUNDS.grow(75).merge(Uplands.RAVINE_BOUNDS.grow(44))
 var layout:=Layout.new();var checked:=0;var invalid:=0;var forbidden:=0;var maximum_error:=0.0
 var cache:Dictionary={}
 for tile:Node3D in landscape.get_node("NatureTiles").get_children():
  var origin:=Vector2(tile.position.x,tile.position.z)
  if not Rect2(origin,Vector2.ONE*Layout.TILE).intersects(bounds):continue
  var parts:=str(tile.name).split("_")
  var identity:="Terrain_%02d_%02d"%[int(parts[1]),int(parts[2])]
  if not cache.has(identity):
   var mesh:Mesh=landscape.get_node("TerrainTiles/"+identity).mesh
   cache[identity]=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var vertices:PackedVector3Array=cache[identity];var step:=vertices[1].x-vertices[0].x
  for batch:MultiMeshInstance3D in tile.find_children("Grass*","MultiMeshInstance3D",true,false):
   for i in batch.multimesh.instance_count:
    var transform:=batch.multimesh.get_instance_transform(i)
    if is_zero_approx(transform.basis.determinant()):invalid+=1;continue
    var at:Vector3=batch.global_transform*transform.origin
    var point:=Vector2(at.x,at.z).clamp(origin+Vector2.ONE*.001,origin+Vector2.ONE*(Layout.TILE-.001))
    var ground:=Grass.baked_frame(vertices,origin,point,step,Layout.TILE)
    maximum_error=maxf(maximum_error,absf(at.y-(ground.origin.y-.018)))
    if not Grass.placement_allowed(layout,point,layout.height(point.x,point.y),layout.road_distance(point.x,point.y)):forbidden+=1
    checked+=1
 print("PORT UPLANDS GRASS roots=",checked," singular_instances=",invalid," forbidden=",forbidden," maximum_root_error_m=",maximum_error)
 var okay:=checked>0 and invalid==0 and forbidden==0 and maximum_error<.025
 landscape.queue_free();await process_frame
 print("PORT UPLANDS GRASS ","PASS" if okay else "FAIL")
 quit(0 if okay else 1)
