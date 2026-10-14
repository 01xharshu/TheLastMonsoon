extends "res://tools/world/bake_civil_lines_region.gd"
## Incremental saved terrain/collision update; other world regions remain untouched.
const Uplands = preload("res://world/suryagarh/port_village_uplands.gd")
var surface_cache:Dictionary={}
func bake() -> void:
 if DisplayServer.get_name()=="headless":
  push_error("PORT UPLANDS BAKE requires the native renderer to retain MultiMesh transforms")
  quit(2);return
 world.free()
 world=load(OUT+"landscape.scn").instantiate();root.add_child(world)
 terrain_material=load(OUT+"terrain_material.tres")
 var terrain:Node3D=world.get_node("TerrainTiles")
 var bounds:=Uplands.BOUNDS.grow(75.0).merge(Uplands.RAVINE_BOUNDS.grow(44.0)).intersection(Rect2(Vector2.ONE*-Layout.HALF,Vector2.ONE*Layout.SIZE))
 var first:=Vector2i((bounds.position+Vector2.ONE*Layout.HALF)/Layout.TILE)
 var last:=Vector2i((bounds.end-Vector2.ONE*.001+Vector2.ONE*Layout.HALF)/Layout.TILE)
 for tz in range(first.y,last.y+1):
  for tx in range(first.x,last.x+1):
   var tile:Node3D=terrain.get_node("Terrain_%02d_%02d"%[tx,tz])
   old_shapes[Vector2i(tx,tz)]=tile.get_node("GroundCollision").get_child(0).shape
   terrain.remove_child(tile);tile.free()
   bake_tile(Vector2(-Layout.HALF+tx*Layout.TILE,-Layout.HALF+tz*Layout.TILE),tx,tz,terrain)
  print("PORT UPLANDS TERRAIN ROW ",tz)
 for batch:MultiMeshInstance3D in world.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
  if str(batch.name).begins_with("Grass"):continue # Rebuild rooted grass; zero bases make its inverse-matrix shader invalid.
  var original:=batch.multimesh
  var copy:MultiMesh
  for i in original.instance_count:
   var t:=original.get_instance_transform(i)
   if is_zero_approx(t.basis.determinant()):continue
   var p:Vector3=batch.global_transform*t.origin
   if not bounds.has_point(Vector2(p.x,p.z)):continue
   if copy==null:copy=original.duplicate()
   if road_clearance(Vector2(p.x,p.z)):
    t.basis=Basis.IDENTITY.scaled(Vector3.ZERO);cleared+=1
   else:
    var burial:float=.12 if str(batch.name)=="BroadleafTrees" else t.basis.get_scale().y*.5
    t.origin.y=surface_height(Vector2(p.x,p.z))-burial-batch.global_position.y
   copy.set_instance_transform(i,t)
  if copy!=null:batch.multimesh=copy
 for body:StaticBody3D in world.get_node("NatureTiles").find_children("*","StaticBody3D",true,false):
  var p:=body.global_position
  if not bounds.has_point(Vector2(p.x,p.z)):continue
  if road_clearance(Vector2(p.x,p.z)):
   body.get_parent().remove_child(body);body.free()
  else:
   var shape:Shape3D=body.get_child(0).shape
   var offset:float=shape.height/1.8*.8 if shape is CylinderShape3D else -body.basis.get_scale().y*.5
   body.position.y=surface_height(Vector2(p.x,p.z))+offset-body.get_parent().global_position.y
 nature_meshes["grass_bermuda_01"]=preload("res://world/suryagarh/grass_blades.gd").make_mesh()
 nature_meshes["grass_detail"]=preload("res://world/suryagarh/grass_blades.gd").make_mesh(true)
 for tz in range(first.y,last.y+1):
  for tx in range(first.x,last.x+1):
   var tile:Node3D=world.get_node("NatureTiles/Nature_%02d_%02d"%[tx,tz])
   for child in tile.get_children():
    if str(child.name).begins_with("GrassCore") or str(child.name).begins_with("GrassDetail"):
     tile.remove_child(child);child.free()
   bake_grass(Vector2(-Layout.HALF+tx*Layout.TILE,-Layout.HALF+tz*Layout.TILE),tx,tz,tile)
  print("PORT UPLANDS ROOTED GRASS ROW ",tz)
 var image:Image=(load(OUT+"road_mask.res") as Texture2D).get_image()
 var pixels:=image.get_width()
 for z in range(pixels):
  for x in range(pixels):
   var p:Vector2=(Vector2(x+.5,z+.5)/pixels-Vector2.ONE*.5)*Layout.SIZE
   if not bounds.has_point(p):continue
   var paint:=1.0-smoothstep(3.5,5.5,road_edge(Vector3(p.x,0,p.y),[Uplands.MAIN]))
   for route in Uplands.SHORTCUTS.values():paint=maxf(paint,1.0-smoothstep(.8,2.0,road_edge(Vector3(p.x,0,p.y),[route])))
   if Uplands.RAVINE_BOUNDS.has_point(p):paint=maxf(paint,1.0-smoothstep(3.0,4.5,absf(p.y-385.0)))
   if Rect2(Vector2(-362,390),Vector2(24,115)).has_point(p):paint=maxf(paint,1.0-smoothstep(3.0,4.5,absf(p.x+350.0)))
   if Rect2(Vector2(-560,468),Vector2(222,24)).has_point(p):paint=maxf(paint,1.0-smoothstep(3.0,4.5,absf(p.y-480.0)))
   var retained:float=1.0-smoothstep(2.0,4.8,layout.road_distance(p.x,p.y))
   if p.y>369.0 and p.y<500.0 and absf(p.x-layout.road_x(p.y))<6.0:retained=0.0
   image.set_pixel(x,z,Color(maxf(retained,paint),0,0))
 var mask:=ImageTexture.create_from_image(image);save_resource(mask,"road_mask.res")
 terrain_material.set_shader_parameter("road_mask_tex",mask);save_resource(terrain_material,"terrain_material.tres")
 var existing:=world.get_node_or_null("PortRavineBridge")
 if existing!=null:existing.free()
 var bridge:=preload("res://world/suryagarh/port_ravine_bridge.gd").build()
 world.add_child(bridge);bridge.owner=world
 for node in bridge.find_children("*","",true,false):node.owner=world
 var packed:=PackedScene.new();assert(packed.pack(world)==OK);save_resource(packed,"landscape.scn")
 print("PORT UPLANDS BAKE PASS tiles=",old_shapes.size()," cleared=",cleared)
 quit()
func road_clearance(p:Vector2) -> bool:
 if Uplands.RAVINE_BOUNDS.has_point(p) or Rect2(Vector2(-362,390),Vector2(24,115)).has_point(p) or Rect2(Vector2(-560,468),Vector2(222,24)).has_point(p):return true
 if road_edge(Vector3(p.x,0,p.y),[Uplands.MAIN])<9.0:return true
 for route in Uplands.SHORTCUTS.values():
  if road_edge(Vector3(p.x,0,p.y),[route])<4.0:return true
 return false

func surface_height(p:Vector2) -> float:
 var key:=Vector2i(floori((p.x+Layout.HALF)/Layout.TILE),floori((p.y+Layout.HALF)/Layout.TILE))
 if not surface_cache.has(key):
  var mesh:Mesh=world.get_node("TerrainTiles/Terrain_%02d_%02d"%[key.x,key.y]).mesh
  surface_cache[key]=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var vertices:PackedVector3Array=surface_cache[key]
 var origin:=Vector2(-Layout.HALF+key.x*Layout.TILE,-Layout.HALF+key.y*Layout.TILE)
 var at:=p.clamp(origin+Vector2.ONE*.001,origin+Vector2.ONE*(Layout.TILE-.001))
 return preload("res://world/suryagarh/grass_blades.gd").baked_frame(vertices,origin,at,vertices[1].x-vertices[0].x,Layout.TILE).origin.y
