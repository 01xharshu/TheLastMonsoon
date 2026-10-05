"""Use outward ray projection to prevent nearest-point strip fragmentation."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/characters/arjun/reference_fit/boot_contact_2026-10-01';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/Arjun/reference_fit/arjun_eye_moustache_candidate.blend'))
import sys
sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
ensure_full_body()
disabled=[]
for o in bpy.data.objects:
 if o.name.startswith('Arjun_Boot_'):
  for mod in o.modifiers:
   if mod.type=='ARMATURE':disabled.append((mod,mod.show_viewport));mod.show_viewport=False
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get();trees={}
for sign in [-1,1]:
 o=bpy.data.objects['Arjun_Boot_'+str(sign)].evaluated_get(deps);m=o.to_mesh();trees['l' if sign>0 else 'r']=BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[tuple(p.vertices) for p in m.polygons]);o.to_mesh_clear()
for mod,state in disabled:mod.show_viewport=state
bpy.context.view_layer.update()
misses=0;count=0
for obj in list(bpy.data.objects):
 if not(obj.name.startswith('Flat boot wrap ') or obj.name.startswith('Flat vamp strap ')):continue
 side=obj.name.split()[-1][0];cx=.195 if side=='l' else -.195
 for v in obj.data.vertices:
  q=v.co.copy()
  if obj.name.startswith('Flat vamp'):
   origin=Vector((q.x,q.y,.45));direction=Vector((0,0,-1));outward=Vector((0,0,1))
  else:
   outward=Vector((q.x-cx,q.y+.006,0)).normalized();origin=Vector((cx,-.006,q.z))+outward*.30;direction=-outward
  hit,n,idx,d=trees[side].ray_cast(origin,direction)
  if hit is None:misses+=1;continue
  if n.dot(outward)<0:n=-n
  v.co=hit+n*.003;count+=1
  t=max(0,min(1,(v.co.z-.145)/.13))
  for group in obj.vertex_groups:group.remove([v.index])
  for name,weight in [('foot_'+side,1-t),('calf_'+side,t)]:
   group=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name);group.add([v.index],weight,'REPLACE')
 # Thin real leather; original large clearance made strips look inflated.
 for mod in obj.modifiers:
  if mod.type=='SOLIDIFY':mod.thickness=.0012
hair=bpy.data.objects['Arjun_FineMoustacheStrands']
ztop=max(v.co.z for v in hair.data.vertices);extent=max(abs(v.co.x) for v in hair.data.vertices)
for v in hair.data.vertices:
 u=min(1,abs(v.co.x)/extent);v.co.z=ztop-(ztop-v.co.z)*(.25+.75*(1-u*u))
scene=bpy.context.scene;c=scene.camera;scene.render.resolution_x=700;scene.render.resolution_y=700;scene.cycles.samples=16;c.data.ortho_scale=.36
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_boot_contact_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('boot_front',(.195,-2,.18)),('boot_side',(2,-.07,.18))]:
 c.location=pos;c.rotation_euler=(Vector((.195,-.07,.16))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
scene.render.resolution_x=900;scene.render.resolution_y=900;c.data.ortho_scale=.4;c.location=(0,-2,1.60);c.rotation_euler=(Vector((0,0,1.60))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'face.png');bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','candidate':str(candidate.relative_to(ROOT)),'projected_vertices':count,'misses':misses,'exact_match':False,'runtime_replaced':False},indent=2)+'\n')
