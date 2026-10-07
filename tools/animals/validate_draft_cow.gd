extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var ground:=StaticBody3D.new();world.add_child(ground)
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100);collision.shape=box;collision.position.y=-.1;ground.add_child(collision)
 var cart:=preload("res://vehicles/bullock_cart.gd").new();world.add_child(cart)
 await process_frame
 cart.process_mode=Node.PROCESS_MODE_DISABLED
 await physics_frame
 var errors:Array[String]=[]
 if cart.solvers.size()!=2:errors.append("paired solvers missing")
 var lows:=[1.0,1.0];var highs:=[0.0,0.0]
 for frame in 600:
  var speed:=1.6 if frame>180 else 0.0
  cart.position.z-=speed/60.0
  if frame>360:cart.rotation.y+=.001
  cart.set_forward_motion(speed,1.0/60.0)
  for index in cart.solvers.size():
   var solver:Node=cart.solvers[index]
   if solver.breath_index<0:errors.append("missing draft breathing");break
   var value:float=solver.breathing_mesh.get_blend_shape_value(solver.breath_index)
   lows[index]=minf(lows[index],value);highs[index]=maxf(highs[index],value)
   for bone in solver.rig.get_bone_count():
    if not solver.rig.get_bone_global_pose(bone).is_finite():errors.append("invalid draft pose")
 for index in 2:
  if lows[index]>.05 or highs[index]<.95:errors.append("draft breathing does not cycle")
 var neck_top:float=-INF
 var skin:MeshInstance3D=cart.oxen[0].find_child("Continuous cow skin",true,false)
 for vertex:Vector3 in skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  if absf(vertex.x)<.07 and absf(vertex.z+.88)<.03:neck_top=maxf(neck_top,vertex.y)
 var yoke:MeshInstance3D=cart.visual_root.get_node("DraughtYoke")
 var gap:float=yoke.position.y-.06-(neck_top-.025)
 if gap<0 or gap>.010:errors.append("yoke neck clearance")
 print("DRAFT_YOKE_GAP_M ",gap)
 print("BULLOCK MUD COW FIXTURE ","PASS" if errors.is_empty() else "FAIL",errors," breathing ranges ",lows," / ",highs)
 world.queue_free();quit(0 if errors.is_empty() else 1)
