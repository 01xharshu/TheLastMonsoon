"""Check exact nonadjacent self-crossings in candidate upper fabric."""
import bpy,sys
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_upper_self_fit import self_hits,points_of
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
garment=args[args.index('--garment')+1] if '--garment' in args else 'Street coherent cotton blouse and pallu'
source=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE';obj=bpy.data.objects.get(garment)
if obj is None or obj.type!='MESH' or obj.get('street_source_only',False):raise RuntimeError('Missing active garment: '+garment)
obj.data.calc_loop_triangles();faces=[tuple(t.vertices) for t in obj.data.loop_triangles]
if not faces:raise RuntimeError('Garment has no triangles: '+garment)
total=0
for swing in [0.,-.35,-.175,.175,.35]:
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for side,sign in [('l',1),('r',-1)]:
  bone=rig.pose.bones.get('upperarm_'+side)
  if bone:bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
 bpy.context.view_layer.update();hits=self_hits(points_of(obj),faces);total+=hits;print('CANDIDATE_CLOTH_SELF',slug,garment,swing,hits,flush=True)
if total:raise RuntimeError('Cloth self intersections in '+garment+': '+str(total))
