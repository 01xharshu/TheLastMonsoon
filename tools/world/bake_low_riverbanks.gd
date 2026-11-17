extends "res://tools/world/bake_landscape.gd"
## Patch existing terrain samples locally, preserving other mesh and scene state.
func bake() -> void:
 if DisplayServer.get_name()=="headless":push_error("Low-bank bake requires native renderer");quit(1);return
 world.free();world=load(OUT+"landscape.scn").instantiate();root.add_child(world)
 var terrain:Node3D=world.get_node("TerrainTiles")
 var records:Dictionary={}
 for tile_id in [Vector2i(5,5),Vector2i(6,7),Vector2i(6,8)]:
  var tile:MeshInstance3D=terrain.get_node("Terrain_%02d_%02d"%[tile_id.x,tile_id.y])
  var collider:CollisionShape3D=tile.get_node("GroundCollision").get_child(0)
  var old_shape:HeightMapShape3D=collider.shape
  var original:PackedFloat32Array=old_shape.map_data.duplicate()
  var grid:int=old_shape.map_width-1;var step:float=Layout.TILE/grid
  var arrays:Array=tile.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var tangent:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
  var heights:PackedFloat32Array=original.duplicate();var changed:=0
  for z in grid+1:
   for x in grid+1:
    var i:int=z*(grid+1)+x;var point:Vector3=tile.position+vertices[i]
    var weight:float=layout.low_bank_weight(point.x,point.z)
    if weight>0.000001:
     var h:float=layout.height(point.x,point.z)
     if absf(h-vertices[i].y)>0.00001:
      vertices[i].y=h;heights[i]=h/step;changed+=1
    if weight>0 or layout.low_bank_weight(point.x-2,point.z)>0 or layout.low_bank_weight(point.x+2,point.z)>0 or layout.low_bank_weight(point.x,point.z-2)>0 or layout.low_bank_weight(point.x,point.z+2)>0:
     var n:Vector3=layout.normal(point.x,point.z);normals[i]=n
     var t:Vector3=Vector3(n.y,-n.x,0).normalized()
     tangent[i*4]=t.x;tangent[i*4+1]=t.y;tangent[i*4+2]=t.z
  # Existing border skirts retain the old vertex topology and follow updated edges.
  var offset:int=(grid+1)*(grid+1)
  for edge in 4:
   for k in grid:
    var a:int;var b:int
    match edge:
     0:a=k;b=k+1
     1:a=k*(grid+1)+grid;b=(k+1)*(grid+1)+grid
     2:a=grid*(grid+1)+k+1;b=a-1
     _:a=(k+1)*(grid+1);b=k*(grid+1)
    var ia:int=offset+(edge*grid+k)*2
    vertices[ia].y=vertices[a].y-5;vertices[ia+1].y=vertices[b].y-5
    normals[ia]=normals[a];normals[ia+1]=normals[b]
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangent
  var builder:=ImporterMesh.new();builder.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},tile.mesh.surface_get_material(0));builder.generate_lods(60.0,60.0,[])
  var mesh:ArrayMesh=builder.get_mesh();var filename:String="lowbank_tile_%02d_%02d.res"%[tile_id.x,tile_id.y]
  save_resource(mesh,filename);tile.mesh=mesh
  var replacement:HeightMapShape3D=old_shape.duplicate();replacement.map_data=heights;collider.shape=replacement
  records[tile_id]={"origin":Vector2(tile.position.x,tile.position.z),"grid":grid,"step":step,"heights":original,"new_heights":heights}
  print("LOW_BANK_TILE ",tile_id," samples=",changed)
 # Shift existing trees, grass, rocks and their collision on changed ground.
 var adjusted:=0
 for batch:MultiMeshInstance3D in world.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
  var copy:MultiMesh
  for i in batch.multimesh.instance_count:
   var transform:=batch.multimesh.get_instance_transform(i)
   if is_zero_approx(transform.basis.determinant()):continue
   var position:Vector3=batch.global_transform*transform.origin
   if layout.low_bank_weight(position.x,position.z)<=0.000001:continue
   var old:float=sample_height(position.x,position.z,records,"heights")
   var delta:float=sample_height(position.x,position.z,records,"new_heights")-old
   if absf(delta)<.001:continue
   if copy==null:copy=batch.multimesh.duplicate()
   transform.origin.y+=delta;copy.set_instance_transform(i,transform);adjusted+=1
  if copy!=null:batch.multimesh=copy
 for body:StaticBody3D in world.get_node("NatureTiles").find_children("*","StaticBody3D",true,false):
  var position:=body.global_position
  if layout.low_bank_weight(position.x,position.z)<=0.000001:continue
  body.position.y+=sample_height(position.x,position.z,records,"new_heights")-sample_height(position.x,position.z,records,"heights")
 var packed:=PackedScene.new();assert(packed.pack(world)==OK)
 save_resource(packed,"landscape.scn")
 print("LOW_BANK_BAKE COMPLETE nature_adjusted=",adjusted);world.queue_free();await process_frame;quit()

func sample_height(x:float,z:float,records:Dictionary,field:String)->float:
 for key in records:
  var rec:Dictionary=records[key];var local:Vector2=(Vector2(x,z)-rec.origin)/float(rec.step);var n:int=rec.grid
  if local.x<0 or local.y<0 or local.x>n or local.y>n:continue
  var ix:int=clampi(int(floor(local.x)),0,n-1);var iz:int=clampi(int(floor(local.y)),0,n-1)
  var values:PackedFloat32Array=rec[field]
  var a:float=values[iz*(n+1)+ix];var b:float=values[iz*(n+1)+ix+1]
  var c:float=values[(iz+1)*(n+1)+ix];var d:float=values[(iz+1)*(n+1)+ix+1]
  return lerpf(lerpf(a,b,local.x-ix),lerpf(c,d,local.x-ix),local.y-iz)*float(rec.step)
 return layout.height(x,z)
