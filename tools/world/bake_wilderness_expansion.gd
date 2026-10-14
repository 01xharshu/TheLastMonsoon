extends "res://tools/world/bake_landscape.gd"
## Additive ring. Original landscape, population, plots, roads and editable sources stay intact.
const EXPANSION_OUT="res://world/suryagarh/generated/wilderness_expansion/"
func save_resource(resource:Resource,file:String) -> void:
 assert(ResourceSaver.save(resource,EXPANSION_OUT+file,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)==OK,"Expansion save failed: "+file)
func bake() -> void:
 if DisplayServer.get_name()=="headless":push_error("Native rendering required for saved MultiMesh buffers");quit(1);return
 DirAccess.make_dir_recursive_absolute(EXPANSION_OUT)
 rng.seed=185703
 world.name="WildernessExpansion"
 terrain_material=load("res://world/suryagarh/generated/terrain_material.tres")
 for slug in ["island_tree_02","boulder_01"]:
  var model:Node=load("res://assets/nature/models/"+slug+".glb").instantiate()
  nature_meshes[slug]=model.find_children("*","MeshInstance3D",true,false)[0].mesh;model.free()
 nature_meshes["grass_bermuda_01"]=preload("res://world/suryagarh/grass_blades.gd").make_mesh()
 nature_meshes["grass_detail"]=preload("res://world/suryagarh/grass_blades.gd").make_mesh(true)
 for slug in nature_meshes:
  var mesh:Mesh=nature_meshes[slug]
  mesh.resource_local_to_scene=false
  mesh.take_over_path(EXPANSION_OUT+slug+".res")
  save_resource(mesh,slug+".res")
  print("WILDERNESS SHARED MESH ",slug," path=",mesh.resource_path," local=",mesh.resource_local_to_scene)
 var terrain:=Node3D.new();terrain.name="TerrainTiles";attach(terrain,world)
 var nature:=Node3D.new();nature.name="NatureTiles";attach(nature,world)
 var count:=0
 for z in range(-2,14):
  for x in range(-2,14):
   if x>=0 and x<12 and z>=0 and z<12:continue
   var origin:=Vector2(-Layout.CORE_HALF+x*Layout.TILE,-Layout.CORE_HALF+z*Layout.TILE)
   bake_tile(origin,x,z,terrain);bake_nature(origin,x,z,nature);count+=1
   # External nature scenes keep individual source assets well below regular Git limits.
   var tile:Node=nature.get_child(nature.get_child_count()-1)
   for child in tile.find_children("*","",true,false):child.owner=tile
   var packed_tile:=PackedScene.new();assert(packed_tile.pack(tile)==OK)
   var file:="nature_%d_%d.scn"%[x,z];save_resource(packed_tile,file);tile.free()
   var restored:Node=load(EXPANSION_OUT+file).instantiate();attach(restored,nature)
  print("WILDERNESS ROW ",z," tiles=",count)
 bake_horizon()
 var packed:=PackedScene.new();assert(packed.pack(world)==OK);save_resource(packed,"wilderness_expansion.scn")
 print("WILDERNESS BAKE PASS tiles=",count," size=",Layout.SIZE," trees=",tree_count," rocks=",rock_count," grass=",grass_count)
 world.free();quit()

func bake_grass(origin: Vector2,tx: int,tz: int,tile: Node3D) -> void:
 # 18 m batches keep nearby detail from drawing whole 36 m patches.
 var terrain_tile: MeshInstance3D = world.get_node("TerrainTiles/Terrain_%02d_%02d" % [tx,tz])
 var ground_vertices: PackedVector3Array = terrain_tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var sampling_step := ground_vertices[1].x-ground_vertices[0].x
 var grass_rng := RandomNumberGenerator.new()
 grass_rng.seed = 1857+tx*149+tz*1879
 for gz in 8:
  for gx in 8:
   var grass: Array[Transform3D] = []
   for i in 96:
    var p := origin + Vector2(gx*18+grass_rng.randf_range(0,18),gz*18+grass_rng.randf_range(0,18))
    var h: float = layout.height(p.x,p.y)
    var road_distance: float = layout.road_distance(p.x,p.y)
    var grass_rules = preload("res://world/suryagarh/grass_blades.gd")
    if not grass_rules.placement_allowed(layout,p,h,road_distance): continue
    var cover: float = grass_rules.habitat_density(layout,p,road_distance)
    if grass_rng.randf() > cover: continue
    var size := Vector3(grass_rng.randf_range(.85,1.2),grass_rng.randf_range(.7,1.25),grass_rng.randf_range(.85,1.2))
    var habitat: float = preload("res://world/suryagarh/grass_blades.gd").habitat_height(layout,p,road_distance)
    size.y *= habitat
    # Long growth spreads into wider, bending tussocks rather than thin poles.
    var spread: float = 1.0+(habitat-1.0)*.65
    size.x *= spread
    size.z *= spread
    var frame := preload("res://world/suryagarh/grass_blades.gd").baked_frame(ground_vertices,origin,p,sampling_step,Layout.TILE)
    var ground_normal: Vector3 = frame.basis.z.cross(frame.basis.x).normalized()
    if ground_normal.y < .78: continue # Bare steep cuts and rock faces.
    frame.origin -= Vector3(origin.x,.018,origin.y)
    frame.basis = frame.basis*Basis(Vector3.UP,grass_rng.randf_range(0,TAU)).scaled(size)
    grass.append(frame)
   grass_count += grass.size()
   multimesh_batch(nature_meshes["grass_bermuda_01"],grass,tile,"GrassCore_%d_%d" % [gx,gz],85)
   multimesh_batch(nature_meshes["grass_detail"],grass,tile,"GrassDetail_%d_%d" % [gx,gz],45)


func bake_horizon() -> void:
 # Coarse non-playable continuation keeps the map edge out of the ground-level skyline.
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(-4320, 4320, 96):
  for x in range(-4320, 4320, 96):
   if x >= -Layout.HALF and x < Layout.HALF and z >= -Layout.HALF and z < Layout.HALF: continue
   for offset in [Vector2(0,0),Vector2(96,0),Vector2(0,96),Vector2(96,0),Vector2(96,96),Vector2(0,96)]:
    var p: Vector2 = Vector2(x,z) + offset
    st.set_normal(layout.normal(p.x,p.y))
    st.set_uv(p/8)
    st.add_vertex(Vector3(p.x,layout.height(p.x,p.y),p.y))
 st.generate_tangents()
 st.set_material(terrain_material)
 var horizon := MeshInstance3D.new()
 horizon.name = "DistantTerrain_NoCollision"
 horizon.mesh = st.commit()
 horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 attach(horizon, world)

