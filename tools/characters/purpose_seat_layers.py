"""Layer clearance for the clerk waistcoat over its fitted cotton shirt."""
import bpy
from mathutils.bvhtree import BVHTree
from purpose_local_cloth import _fit_pose

def fit_outer_waistcoat(rig,body,shirt,vest):
 for obj in bpy.data.objects:
  if obj.type=='MESH' and obj.data.shape_keys:
   for key in obj.data.shape_keys.key_blocks:
    if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
 for sample in range(121):
  frame=1+sample*.5;bpy.context.scene.frame_set(int(frame),subframe=frame%1)
  keyname='Seat cloth %02d'%sample
  shirt.data.shape_keys.key_blocks[keyname].value=1;key=vest.data.shape_keys.key_blocks[keyname];key.value=1
  bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();points=[];faces=[]
  for obj in [body,shirt]:
   ev=obj.evaluated_get(dg);mesh=ev.to_mesh();offset=len(points)
   points.extend(ev.matrix_world@v.co for v in mesh.vertices)
   faces.extend(tuple(offset+i for i in p.vertices) for p in mesh.polygons);ev.to_mesh_clear()
  _fit_pose(rig,vest,BVHTree.FromPolygons(points,faces),key,vertex_priority=True)
  shirt.data.shape_keys.key_blocks[keyname].value=0;key.value=0
  print('CLERK_SEAT_LAYER',sample,flush=True)
