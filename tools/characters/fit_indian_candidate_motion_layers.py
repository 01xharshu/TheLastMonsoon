"""Bounded repeated garment separation for sampled deformations, no body edits."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_layer_fit import separate_layers
from river_triangle_contact import crosses
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
outer_name=args[args.index('--outer')+1];inner_name=args[args.index('--inner')+1]
gap=float(args[args.index('--gap')+1]) if '--gap' in args else .008
if not .004<=gap<=.02:raise ValueError('Construction gap outside allowed range')
path=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
outer=bpy.data.objects[outer_name];inner=bpy.data.objects[inner_name]
if not outer.data.shape_keys:outer.shape_key_add(name='Basis')
key=outer.data.shape_keys.key_blocks['Basis'];original=[v.co.copy() for v in key.data]
def pose(swing):
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for side,sign in [('l',1),('r',-1)]:
  for prefix in ['thigh_','upperarm_']:
   b=rig.pose.bones.get(prefix+side)
   if b:b.rotation_mode='QUATERNION';b.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
 bpy.context.view_layer.update()
def surface(obj):
 e=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=e.to_mesh();mesh.calc_loop_triangles()
 points=[e.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles];e.to_mesh_clear()
 return points,faces,BVHTree.FromPolygons(points,faces,all_triangles=True)
def crossing():
 a,fa,ta=surface(outer);b,fb,tb=surface(inner)
 return sum(crosses([a[i] for i in fa[x]],[b[i] for i in fb[y]]) for x,y in ta.overlap(tb))
swings=[0.,-.35,-.175,.175,.35]
for attempt in range(6):
 for swing in swings:
  pose(swing);points,faces,tree=surface(inner)
  if crossing():separate_layers(rig,outer,key,points,faces,tree,gap=gap,reserve_margin=False)
 counts=[]
 for swing in swings:pose(swing);counts.append(crossing())
 maximum=max((v.co-p).length for v,p in zip(key.data,original))
 print('MOTION_LAYER_FIT',slug,attempt,'crossings',counts,'max_mm',maximum*1000,flush=True)
 if maximum>.06:raise RuntimeError('Exceeded 60mm bounded correction; no candidate saved')
 if not any(counts):break
else:raise RuntimeError('Multi-pose separation did not converge; no candidate saved')
for v,k in zip(outer.data.vertices,key.data):v.co=k.co
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('MOTION_LAYER_FIT_SAVED',slug,outer_name,flush=True)
