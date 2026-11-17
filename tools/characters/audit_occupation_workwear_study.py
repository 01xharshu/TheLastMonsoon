"""Conservative body-volume screen for the disposable occupation garment study.

This is a rejection screen, not a replacement for exact layer, motion and
native rendering checks. The study path must be under the OS temp directory.
"""
import json
import sys
import tempfile
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_cloth_volume import inside_surface,VolumeSurface
from river_triangle_contact import crosses
source=Path(sys.argv[sys.argv.index('--')+1]).resolve()
if not source.is_relative_to(Path(tempfile.gettempdir()).resolve()): raise ValueError('Study must be temporary')
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=bpy.data.objects['artisan_complete_MakeHuman_body']
cloth=bpy.data.objects['Workwear transfer study']
foundation=bpy.data.objects['Street opaque foundation']
rig.data.pose_position='POSE'
results=[]
for label,leg,arm in [('idle',0.0,0.0),('walk',.30,.25),('seated',1.0,.5)]:
 if foundation.data.shape_keys:
  key=foundation.data.shape_keys.key_blocks.get('Study seated foundation')
  if key:key.value=1.0 if label=='seated' else 0.0
  key=foundation.data.shape_keys.key_blocks.get('Study walk foundation')
  if key:key.value=1.0 if label=='walk' else 0.0
 if cloth.data.shape_keys:
  key=cloth.data.shape_keys.key_blocks.get('Study seated correction')
  if key:key.value=1.0 if label=='seated' else 0.0
  walk_key=cloth.data.shape_keys.key_blocks.get('Study walk correction')
  if walk_key:walk_key.value=1.0 if label=='walk' else 0.0
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for side,sign in [('l',1),('r',-1)]:
  rotations=[('thigh_'+side,-1.35),('calf_'+side,1.5),('upperarm_'+side,-.45),('lowerarm_'+side,-.85)] if label=='seated' else [('thigh_'+side,leg*sign),('upperarm_'+side,arm*sign)]
  for name,angle in rotations:
   bone=rig.pose.bones.get(name)
   if bone:
    axis=bone.bone.matrix_local.to_3x3().inverted() @ Vector((1,0,0))
    bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle)
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 skin=body.evaluated_get(dg);surface=skin.to_mesh();surface.calc_loop_triangles()
 points=[skin.matrix_world@v.co for v in surface.vertices]
 triangles=[tuple(t.vertices) for t in surface.loop_triangles]
 volume=VolumeSurface.FromPolygons(points,triangles,all_triangles=True,strict=True)
 evaluated=cloth.evaluated_get(dg);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
 cloth.data.calc_loop_triangles()
 source_triangles={tuple(sorted(tri.vertices)) for tri in cloth.data.loop_triangles}
 evaluated_triangles={tuple(sorted(tri.vertices)) for tri in mesh.loop_triangles}
 print('OCCUPATION_TRIANGULATION',label,'different_triangles',
       len(source_triangles.symmetric_difference(evaluated_triangles)),flush=True)
 verts=[evaluated.matrix_world@v.co for v in mesh.vertices]
 probes=verts+[sum((verts[i] for i in t.vertices),Vector())/3 for t in mesh.loop_triangles]
 bad=0;worst=0.0
 for p in probes:
  if inside_surface(volume,p):
   near=volume.find_nearest(p)
   if near and near[3]>.001:bad+=1;worst=max(worst,near[3])
 # An entire inner layer can sit outside an outer shell without triangles
 # crossing. Cast outward from the skin through each foundation vertex and
 # require an outer garment surface beyond that vertex. This is conservative
 # and must be reviewed against the actual garment coverage and pose.
 outer=BVHTree.FromPolygons(verts,[tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True)
 inner=foundation.evaluated_get(dg);foundation_mesh=inner.to_mesh()
 uncovered=0;coverage_samples=0;foundation_penetrations=0;uncovered_points=[]
 for v in foundation_mesh.vertices:
  point=inner.matrix_world@v.co
  nearest=volume.find_nearest(point)
  if nearest is None:continue
  if nearest[3]>.001 and inside_surface(volume,point):foundation_penetrations+=1
  skin_point=nearest[0]; direction=point-skin_point; distance=direction.length
  if distance<.001:continue
  direction.normalize();hit=outer.ray_cast(point+direction*.0001,direction,.12)
  coverage_samples+=1
  if hit[0] is None:
   uncovered+=1
   if len(uncovered_points)<8:
    uncovered_points.append({'vertex':v.index,'rest':tuple(round(c,4) for c in foundation.data.vertices[v.index].co),'world':tuple(round(c,4) for c in point),'direction':tuple(round(c,4) for c in direction)})
 # Exact deformed garment crossings complement point/coverage screens.
 foundation_mesh.calc_loop_triangles()
 inner_points=[inner.matrix_world@v.co for v in foundation_mesh.vertices]
 inner_faces=[tuple(t.vertices) for t in foundation_mesh.loop_triangles]
 boundary=int(cloth.get('occupation_upper_vertex_count',1250))
 upper_faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i<boundary for i in t.vertices)]
 lower_faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i>=boundary for i in t.vertices)]
 def intersections(a,fa,b,fb,same=False):
  at=BVHTree.FromPolygons(a,fa,all_triangles=True);bt=at if same else BVHTree.FromPolygons(b,fb,all_triangles=True)
  count=0
  for x,y in at.overlap(bt):
   if same and (x>=y or set(fa[x])&set(fb[y])):continue
   if crosses([a[i] for i in fa[x]],[b[i] for i in fb[y]]):count+=1
  return count
 layer_crossings={
  'foundation_self':intersections(inner_points,inner_faces,inner_points,inner_faces,True),
  'foundation_trousers':intersections(inner_points,inner_faces,verts,lower_faces),
  'foundation_shirt':intersections(inner_points,inner_faces,verts,upper_faces),
  'shirt_trousers':intersections(verts,upper_faces,verts,lower_faces),
  'trousers_self':intersections(verts,lower_faces,verts,lower_faces,True),
  'shirt_self':intersections(verts,upper_faces,verts,upper_faces,True)}
 print('OCCUPATION_UNCOVERED_POINTS',label,json.dumps(uncovered_points),flush=True)
 # Visibility rays include body occlusion and the full garment extent.
 # The short support ray above remains a separate conservative diagnostic.
 directions=[Vector((x,y,z)).normalized() for x in (-1,0,1) for y in (-1,0,1)
             for z in (-1,0,1) if x or y or z]
 def visible(point,include_outer):
  for direction in directions:
   origin=point+direction*.0001
   if volume.ray_cast(origin,direction,4.0)[0] is not None:continue
   if include_outer and outer.ray_cast(origin,direction,4.0)[0] is not None:continue
   return True
  return False
 visibility_points=inner_points+[sum((inner_points[i] for i in face),Vector())/3 for face in inner_faces]
 visible_points=[i for i,point in enumerate(visibility_points) if visible(point,True)]
 control=sum(visible(point,False) for point in visibility_points)
 check_points=[{'sample':i,'world':tuple(round(c,4) for c in visibility_points[i])}
               for i in visible_points[:8]]
 print('OCCUPATION_FOUNDATION_VISIBILITY',label,json.dumps({'probes':len(visibility_points),
       'visible':len(visible_points),'body_only_control':control,'examples':check_points}),flush=True)
 if not control:raise RuntimeError('Foundation visibility negative control did not expose any sample')
 inner.to_mesh_clear()
 results.append({'changed_triangles':len(source_triangles.symmetric_difference(evaluated_triangles)),'pose':label,'samples':len(probes),'penetrations':bad,'worst_mm':round(worst*1000,3),
                 'foundation_visible':len(visible_points),'coverage_negative_control':control,
                 'layer_crossings':layer_crossings,'foundation_samples':coverage_samples,'foundation_uncovered':uncovered,'foundation_penetrations':foundation_penetrations})
 skin.to_mesh_clear();evaluated.to_mesh_clear()
print('OCCUPATION_STUDY_SCREEN',json.dumps(results),flush=True)
if any(x['changed_triangles'] or x['penetrations'] or x['foundation_visible'] or x['foundation_penetrations'] or any(x['layer_crossings'].values()) for x in results):raise RuntimeError('Workwear study fails body or foundation screen; do not promote')
