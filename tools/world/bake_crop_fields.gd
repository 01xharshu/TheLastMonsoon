extends SceneTree
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Crop=preload("res://world/suryagarh/agriculture/crop_mesh.gd")
var layout:=Layout.new()
var terrain: Node3D
var output:=Node3D.new()
var trees: Dictionary={}
var meshes: Dictionary={}
func _initialize() -> void: run.call_deferred()
func attach(node: Node,parent: Node) -> void:
 parent.add_child(node); node.owner=output
func free_ground(p: Vector2) -> bool:
 if layout.field_mask(p.x,p.y)<0.55 or layout.built_area(p.x,p.y) or layout.plot_clearance(p.x,p.y)<16 or layout.road_distance(p.x,p.y)<9: return false
 if layout.normal(p.x,p.y).y<0.96: return false
 var cell:=Vector2i(floori(p.x/12),floori(p.y/12))
 for x in range(-1,2):
  for z in range(-1,2):
   for tree: Vector2 in trees.get(cell+Vector2i(x,z),[]):
    if p.distance_to(tree)<5: return false
 return true
func ground(p: Vector2) -> float:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,150,p.y),Vector3(p.x,-10,p.y))
 var hit:=terrain.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty() or str(hit.collider.name)!="GroundCollision": return INF
 return hit.position.y
func batch(parent: Node3D,kind: String,cell: Vector2i,poses: Array,far: bool) -> void:
 var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true; mm.mesh=meshes[kind]; mm.instance_count=poses.size()
 for i in poses.size():
  mm.set_instance_transform(i,poses[i]); mm.set_instance_custom_data(i,Color(float(i%11)/10,float(i%17)/16,0,0))
 assert(mm.buffer.size()==poses.size()*16,"Renderer did not retain crop transforms/custom data; use native renderer")
 var node:=MultiMeshInstance3D.new(); node.name=("Far_" if far else "Crop_")+str(cell.x)+"_"+str(cell.y)
 node.multimesh=mm; node.position=Vector3(cell.x*24,0,cell.y*24)
 node.visibility_range_begin=165 if far else 0
 node.visibility_range_end=650 if far else 180
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
 node.set_meta("crop_kind",kind); node.set_meta("far_proxy",far)
 attach(node,parent)
func field(label: String,kind: String,center: Vector2,size: Vector2) -> void:
 var node:=Node3D.new(); node.name=label; attach(node,output)
 node.set_meta("crop_kind",kind); node.set_meta("bounds",Rect2(center-size*0.5,size)); node.set_meta("season","late monsoon / kharif candidate")
 node.set_meta("lane_width_m",4.0)
 node.set_meta("walk_route",[center+Vector2(0,-size.y*0.5+4),center,center+Vector2(0,size.y*0.5-4)])
 var rng:=RandomNumberGenerator.new(); rng.seed=1857+absi(label.hash())
 var groups: Dictionary={}; var far_groups: Dictionary={}; var count:=0
 var row_step:=1.45 if kind=="sugarcane" else 1.0
 var plant_step:=1.05 if kind=="sugarcane" else 0.85
 for row in floori((size.x-4)/row_step):
  for col in floori((size.y-4)/plant_step):
   var p:=center-size*0.5+Vector2(2+row*row_step,2+col*plant_step)
   if absf(p.x-center.x)<2.15 or absf(p.y-center.y)<2.15: continue
   p+=Vector2(rng.randf_range(-0.10,0.10),rng.randf_range(-0.12,0.12))
   if not free_ground(p): continue
   var y:=ground(p)
   if is_inf(y): continue
   var cell:=Vector2i(floori(p.x/24),floori(p.y/24))
   var height:=rng.randf_range(0.91,1.14)
   var pose:=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(1,height,1)),Vector3(p.x-cell.x*24,y-0.018,p.y-cell.y*24))
   if not groups.has(cell): groups[cell]=[]; far_groups[cell]=[]
   groups[cell].append(pose)
   if count%8==0: far_groups[cell].append(pose)
   count+=1
 for cell in groups:
  batch(node,kind,cell,groups[cell],false)
  if not far_groups[cell].is_empty(): batch(node,kind,cell,far_groups[cell],true)
 node.set_meta("plant_clumps",count)
 print("FIELD ",label," ",kind," ",count)
func run() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size()!=1 or not args[0].is_absolute_path() or args[0].get_extension()!="scn" or FileAccess.file_exists(args[0]):
  push_error("Supply one new absolute .scn output path after --")
  quit(2)
  return
 if DisplayServer.get_name()=="headless":
  push_error("Crop bake requires the native renderer to retain MultiMesh buffers")
  quit(1); return
 terrain=load("res://world/suryagarh/generated/landscape.scn").instantiate(); root.add_child(terrain)
 for i in 3: await physics_frame
 for node in terrain.find_children("BroadleafTrees","MultiMeshInstance3D",true,false):
  for i in node.multimesh.instance_count:
   var p3: Vector3=node.to_global(node.multimesh.get_instance_transform(i).origin)
   var p:=Vector2(p3.x,p3.z); var cell:=Vector2i(floori(p.x/12),floori(p.y/12))
   if not trees.has(cell): trees[cell]=[]
   trees[cell].append(p)
 output.name="SeasonalCropFields"
 for kind in ["sugarcane","maize","sorghum","sesame"]: meshes[kind]=Crop.new().build(kind)
 for plot in preload("res://world/suryagarh/agriculture/field_layout.gd").plots():
  field(plot[0],plot[1],plot[2],plot[3])
  await process_frame
 var packed:=PackedScene.new(); assert(packed.pack(output)==OK)
 assert(ResourceSaver.save(packed,args[0])==OK)
 print("CROP FIELDS BAKE PASS ",output.get_child_count()," plots")
 output.free(); terrain.queue_free(); await process_frame; quit()
