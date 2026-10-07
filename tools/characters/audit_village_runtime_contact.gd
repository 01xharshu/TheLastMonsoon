extends SceneTree
## Sample imported skinned/morphed triangles rather than source Blender alone.
func _initialize() -> void:call_deferred("run")
func posed_points(node:MeshInstance3D,rig:Skeleton3D,surface:int) -> PackedVector3Array:
 var arrays:=node.mesh.surface_get_arrays(surface)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var base:PackedVector3Array=vertices.duplicate()
 var morphs:=node.mesh.surface_get_blend_shape_arrays(surface)
 for shape in node.mesh.get_blend_shape_count():
  var amount:=node.get_blend_shape_value(shape)
  if is_zero_approx(amount):continue
  var positions:PackedVector3Array=morphs[shape][Mesh.ARRAY_VERTEX]
  for index in vertices.size():vertices[index]+=(positions[index] if node.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE else positions[index]-base[index])*amount
 var palette:Array[Transform3D]=[]
 for bind in node.skin.get_bind_count():
  var bone:=node.skin.get_bind_bone(bind)
  if bone<0:bone=rig.find_bone(node.skin.get_bind_name(bind))
  palette.append(rig.global_transform*rig.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=bones.size()/vertices.size();var points:=PackedVector3Array()
 for index in vertices.size():
  var point:=Vector3.ZERO
  for slot in slots:
   var offset:=index*slots+slot
   if weights[offset]>0:point+=(palette[bones[offset]]*vertices[index])*weights[offset]
  points.append(point)
 return points
func run() -> void:
 var stage:=Node3D.new();root.add_child(stage);var failed:=false
 var slugs:=OS.get_cmdline_user_args()
 if slugs.is_empty():slugs=PackedStringArray(["village_farmer","village_woman","village_fruit_seller","village_weaver_assistant"])
 for slug in slugs:
  var actor:=Node3D.new();actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"));actor.set("candidate_slug",slug);stage.add_child(actor);actor.set_process(false)
  var rig:Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
  var index:=preload("res://tools/characters/village_contact_surface.gd").new()
  var worst:=0.0;var violations:=0;var sample_count:=0
  for walking in [false,true,false]:
   actor.set("walking",walking)
   actor.call("step_motion",.2)
   for sample in 8:
    actor.call("step_motion",.15)
    rig.force_update_all_bone_transforms()
    index.build_body(actor,stage)
    for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
     if node.mesh.get_blend_shape_count()==0:continue
     for surface in node.mesh.get_surface_count():
      var points:=posed_points(node,rig,surface)
      var arrays:=node.mesh.surface_get_arrays(surface)
      var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
      var checks:=points.duplicate()
      for triangle in range(0,ids.size(),3):checks.append((points[ids[triangle]]+points[ids[triangle+1]]+points[ids[triangle+2]])/3.0)
      for point in checks:
       var near:Dictionary=index.nearest(point)
       sample_count+=1
       if not near.is_empty() and near.signed<-.002:
        worst=maxf(worst,-near.signed);violations+=1
  print("VILLAGE_RUNTIME_CONTACT ",slug," samples=",sample_count," violations=",violations," worst_mm=",worst*1000)
  failed=failed or violations>0
  stage.remove_child(actor);actor.free()
 quit(1 if failed else 0)
