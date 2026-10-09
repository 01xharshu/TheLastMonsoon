"""Read-only cloth skinning diagnostic; stdout only."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'))
rig=bpy.data.objects['record_clerk_rig'];rig.animation_data.action=bpy.data.actions['seat_entry'];bpy.context.scene.frame_set(60,subframe=.5)
for name in ['Opaque fitted underwear foundation','Clerk full length trousers','Clerk buttoned sleeveless waistcoat']:
 obj=bpy.data.objects[name]
 for key in obj.data.shape_keys.key_blocks:
  if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=1 if key.name=='Seat cloth 119' else 0
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
 key=obj.data.shape_keys.key_blocks['Seat cloth 119'];worst=0;minimum_det=1.0;maximum_coord=0
 for vertex in obj.data.vertices:
  blend=Matrix.Identity(4)*0;total=0
  for group in vertex.groups:
   bone=rig.pose.bones.get(obj.vertex_groups[group.group].name)
   if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*group.weight;total+=group.weight
  transform=rig.matrix_world@(blend*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world
  minimum_det=min(minimum_det,abs(transform.to_3x3().determinant()))
  maximum_coord=max(maximum_coord,key.data[vertex.index].co.length)
  predicted=transform@key.data[vertex.index].co
  worst=max(worst,(predicted-ev.matrix_world@mesh.vertices[vertex.index].co).length)
 print('SKIN_MODEL_ERROR',name,worst,'min determinant',minimum_det,'max rest coordinate',maximum_coord,'modifiers',[(m.type,getattr(m,'use_deform_preserve_volume',None)) for m in obj.modifiers],flush=True)
 ev.to_mesh_clear()
