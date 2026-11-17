"""Read-only diagnostic of retained MPFB activity foundation against its body."""
import argparse
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_cloth_volume import inside_surface,VolumeSurface
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('role',choices=('artisan','dairyman','scholar','teacher'),nargs='?',default='artisan')
parser.add_argument('--require-clear',action='store_true',help='Fail if either sampled pose has foundation/body penetration')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
role=args.role
geometry_issues=0
if role not in ('artisan','dairyman','scholar','teacher'):raise ValueError('Unknown retained activity source')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/activity_people'/role/(role+'.blend')))
body=bpy.data.objects[role+'_complete_MakeHuman_body'];foundation=bpy.data.objects['Street opaque foundation']
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='POSE'
for label in ('idle','seated'):
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 if label=='seated':
  for side in ('l','r'):
   for prefix,angle in [('thigh_',-1.35),('calf_',1.5),('upperarm_',-.45),('lowerarm_',-.85)]:
    bone=rig.pose.bones.get(prefix+side)
    if bone:
     axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0));bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle)
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 skin=body.evaluated_get(dg);mesh=skin.to_mesh();mesh.calc_loop_triangles()
 tree=VolumeSurface.FromPolygons([skin.matrix_world@v.co for v in mesh.vertices],[tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True)
 inner=foundation.evaluated_get(dg);cloth=inner.to_mesh();gaps=[];penetrations=[]
 for v in cloth.vertices:
  point=inner.matrix_world@v.co;nearest=tree.find_nearest(point)
  if nearest:
   gap=nearest[3];gaps.append(gap)
   if gap>.001 and inside_surface(tree,point):penetrations.append(gap)
 geometry_issues+=len(penetrations)
 gaps.sort()
 print('ACTIVITY_FOUNDATION',json.dumps({'role':role,'pose':label,'samples':len(gaps),'p95_gap_mm':gaps[int(len(gaps)*.95)]*1000,'max_gap_mm':max(gaps)*1000,'penetrations':len(penetrations),'worst_penetration_mm':max(penetrations,default=0)*1000}),flush=True)
 inner.to_mesh_clear();skin.to_mesh_clear()

# Verify the analytic inverse used by the disposable fitter against Blender's
# evaluated deformation. This mutates only in-memory coordinates, restores each
# vertex immediately, and never saves the retained source.
transforms={g.index:bone.matrix@bone.bone.matrix_local.inverted()
            for g in foundation.vertex_groups if (bone:=rig.pose.bones.get(g.name))}
control=Vector((.001,-.001,.001));worst_error=0.0
for index in (0,215,222,400,len(foundation.data.vertices)-1):
 vertex=foundation.data.vertices[index];original=vertex.co.copy()
 def evaluated_point():
  foundation.data.update();foundation.update_tag(refresh={'DATA'});bpy.context.view_layer.update()
  obj=foundation.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=obj.to_mesh()
  result=obj.matrix_world@mesh.vertices[index].co;obj.to_mesh_clear();return result
 before=evaluated_point();blend=Matrix.Identity(4)*0;total=0.0
 for assignment in vertex.groups:
  if assignment.group in transforms:blend+=transforms[assignment.group]*assignment.weight;total+=assignment.weight
 transform=(rig.matrix_world@(blend*(1.0/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@foundation.matrix_world).to_3x3()
 try:
  vertex.co=original+transform.inverted_safe()@control
  error=(evaluated_point()-before-control).length
  worst_error=max(worst_error,error)
 finally:
  vertex.co=original;evaluated_point()
print('ACTIVITY_FOUNDATION_INVERSE',json.dumps({'role':role,'samples':5,'worst_error_mm':worst_error*1000,'passed':worst_error<.00001}),flush=True)
if worst_error>=.00001:raise RuntimeError('Analytic inverse does not match evaluated skin deformation')

print('ACTIVITY_FOUNDATION_GEOMETRY',json.dumps({'role':role,'passed':geometry_issues==0,'penetration_samples':geometry_issues,'scope':'idle and seated-angle vertex screen only'}),flush=True)
if args.require_clear and geometry_issues:raise RuntimeError('Retained foundation fails sampled body clearance')
