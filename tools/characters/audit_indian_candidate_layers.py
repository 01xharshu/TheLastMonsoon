"""Check actual deformed candidate garment surfaces for triangle crossings."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
from river_triangle_contact import crosses
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:]
slug=args[args.index('--identity')+1]
source=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
pairs=[('Street coherent cotton blouse and pallu','Street sari back tail'),('Opaque fitted bra and thong foundation','Street coherent cotton blouse and pallu')]
panel=bpy.data.objects.get('Street sari front pallu')
if panel is not None and not panel.get('street_source_only',False):
 pairs.extend([('Street coherent cotton blouse and pallu',panel.name),
               ('Opaque fitted bra and thong foundation',panel.name),
               ('Street sari back tail',panel.name)])
if '--hair' in args:pairs=[('Street sari back tail','Farmer_hair')]
def tree(name):
 ob=bpy.data.objects[name];ev=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
 points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles]
 tree=BVHTree.FromPolygons(points,faces,all_triangles=True,epsilon=0)
 ev.to_mesh_clear();return tree,points,faces
failures=0
for swing in [0.,-.35,-.175,.175,.35]:
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for side,sign in [('l',1),('r',-1)]:
  for name in ['thigh_','upperarm_']:
   bone=rig.pose.bones.get(name+side)
   if bone:bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
 bpy.context.view_layer.update()
 for first,second in pairs:
  a,pa,fa=tree(first);b,pb,fb=tree(second)
  crossings=sum(crosses([pa[i] for i in fa[x]],[pb[i] for i in fb[y]]) for x,y in a.overlap(b));failures+=crossings
  print('INDIAN_LAYER_AUDIT',slug,swing,first,second,'crossings',crossings,flush=True)
if failures:raise RuntimeError('Candidate garment layers cross: '+str(failures))
