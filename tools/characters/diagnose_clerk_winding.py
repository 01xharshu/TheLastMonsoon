"""Cross-check the disputed seated point using exact solid-angle winding."""
import bpy,sys,math
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
from purpose_cloth_volume import inside_surface,VolumeSurface
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'))
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
faces=native_triangles(rig,[body],ROOT/'characters/npcs/review/record_clerk_seat.glb')[body.name]
frame=1+31/32*60;bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
points=[ev.matrix_world@v.co for v in mesh.vertices]
tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
point=Vector((-.02119288221001625,-.06075752526521683,.4044097363948822))
triangles=np.asarray(points,dtype=np.float64)[np.asarray(faces)]-np.asarray(point)
a,b,c=triangles[:,0],triangles[:,1],triangles[:,2]
la,lb,lc=[np.linalg.norm(v,axis=1) for v in [a,b,c]]
numerator=np.einsum('ij,ij->i',a,np.cross(b,c))
denominator=la*lb*lc+np.einsum('ij,ij->i',a,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a)*lb
winding=np.arctan2(numerator,denominator).sum()/(2*math.pi)
print('CLERK_DISPUTED_WINDING',winding,'ray_inside',inside_surface(tree,point),'distance_mm',tree.find_nearest(point)[3]*1000,flush=True)
ev.to_mesh_clear()

assert abs(winding)<.5, "Disputed point should be outside"
for native in [False,True]:
 transformed=[Vector((p.x,p.z,-p.y)) for p in points] if native else points
 probe=Vector((point.x,point.z,-point.y)) if native else point
 surface=VolumeSurface.FromPolygons(transformed,faces,all_triangles=True,strict=False)
 assert not inside_surface(surface,probe), "Rotation-dependent outside classification"
print("CLERK_VOLUME_ROTATION_REGRESSION PASS",flush=True)
