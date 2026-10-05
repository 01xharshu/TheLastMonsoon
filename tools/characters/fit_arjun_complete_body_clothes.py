"""Fit trouser cloth outside complete MPFB thighs; never change the body."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_complete_body_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0;audit=ensure_full_body();body=bpy.data.objects['Arjun_MakeHuman_Body']
disabled=[]
for m in body.modifiers:
 if m.type=='ARMATURE':disabled.append((m,m.show_viewport));m.show_viewport=False
bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();trees={}
points=[ev.matrix_world@v.co for v in mesh.vertices]
for sign in [-1,1]:
 polygons=[tuple(p.vertices) for p in mesh.polygons if .35<sum(points[i].z for i in p.vertices)/len(p.vertices)<1.06 and sign*sum(points[i].x for i in p.vertices)/len(p.vertices)>.015]
 trees[sign]=BVHTree.FromPolygons(points,polygons)
ev.to_mesh_clear()
for m,state in disabled:m.show_viewport=state
bpy.context.view_layer.update();count=0;maximum=0;misses=0
for obj in bpy.data.objects:
 if not obj.name.startswith('Arjun_HangingDrape_'):continue
 sign=1 if obj.name.endswith('_l') else -1
 for v in obj.data.vertices:
  z=v.co.z
  if not .48<z<1.02:continue
  t=(z-.205)/.765;cx=sign*(.196-.07*t);cy=-.005-.018*math.sin(t*math.pi)
  origin=Vector((cx,cy,z));out=v.co-origin;out.z=0
  radius=out.length
  if radius<1e-8:continue
  out.normalize();hit,n,index,d=trees[sign].ray_cast(origin,out)
  if hit is None:misses+=1;continue
  required=(hit-origin).length+.009
  if radius<required:
   delta=required-radius;v.co+=out*delta;count+=1;maximum=max(maximum,delta)
source_after=ensure_full_body();assert audit['body_coordinate_sha256']==source_after['body_coordinate_sha256']
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_complete_body_fitted_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
audit.update({'candidate':str(candidate.relative_to(ROOT)),'trouser_vertices_fitted':count,'maximum_cloth_delta_m':maximum,'ray_misses':misses,'status':'FULL_BODY_STRUCTURE_PASS_CLOTH_VISUAL_OPEN','runtime_replaced':False})
(ROOT/'docs/characters/arjun/reference_fit/current/full_body_fit_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
