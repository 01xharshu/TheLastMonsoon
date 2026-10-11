"""Fit an isolated clerk outfit with coupled fabric-edge/body constraints.

Only garment shape keys change. The full MPFB body, foundation, physique,
rig and animation remain intact. No test output is retained.
"""
import bpy, sys, runpy
import numpy as np
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
from purpose_cloth_volume import VolumeSurface, inside_surface
SOURCE=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat_physics_candidate.blend'
OUTPUT=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat_shared_candidate.blend'
RUNTIME=ROOT/'characters/npcs/review/record_clerk_seat_shared_candidate.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
cloth=bpy.data.objects['Clerk full length trousers']
# Consolidate nearly coincident fabric seam vertices, preserving all garment
# shape keys and avoiding artificial millimetre-scale strain constraints.
bpy.ops.object.select_all(action='DESELECT');cloth.select_set(True);bpy.context.view_layer.objects.active=cloth
for key in cloth.data.shape_keys.key_blocks:key.value=0
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.006);bpy.ops.object.mode_set(mode='OBJECT')
print('CLERK_SHARED_SEAM_VERTICES',len(cloth.data.vertices),flush=True)
# Preserve the existing simulated drape in world space before repainting.
# Starting from ordinary skinned Basis unnecessarily drives cloth through hips.
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
def world_points(obj):
 ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 points=np.array([tuple(ev.matrix_world@v.co) for v in mesh.vertices]);ev.to_mesh_clear();return points
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
physical={}
for sample in range(0,121,4):
 frame=1+sample*.5;bpy.context.scene.frame_set(int(frame),subframe=frame%1)
 key=cloth.data.shape_keys.key_blocks['Seat cloth %02d'%sample];key.value=1
 bpy.context.view_layer.update();physical[sample]=world_points(cloth);key.value=0
basis=cloth.data.shape_keys.key_blocks['Basis']
# Smooth pelvis-to-thigh inseam weights; only the garment is repainted.
for vertex in cloth.data.vertices:
 point=basis.data[vertex.index].co
 lateral=max(0.0,min(1.0,(.12-abs(point.x))/.09))
 vertical=max(0.0,min(1.0,(point.z-.65)/.08))*max(0.0,min(1.0,(.95-point.z)/.05))
 factor=lateral*lateral*(3-2*lateral)*vertical
 weights={cloth.vertex_groups[g.group].name:g.weight for g in vertex.groups if rig.pose.bones.get(cloth.vertex_groups[g.group].name)}
 total=sum(weights.values())
 for name,value in weights.items():cloth.vertex_groups[name].add([vertex.index],value/max(total,1e-8)*(1-factor),'REPLACE')
 pelvis=cloth.vertex_groups.get('pelvis') or cloth.vertex_groups.new(name='pelvis')
 pelvis.add([vertex.index],weights.get('pelvis',0)/max(total,1e-8)*(1-factor)+factor,'REPLACE')
cloth.data.update()
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
faces=native_triangles(rig,[body],ROOT/'characters/npcs/review/record_clerk_seat_physics_candidate.glb')[body.name]
cloth.data.calc_loop_triangles();tri=np.array([tuple(t.vertices) for t in cloth.data.loop_triangles],dtype=np.int32)
edges=np.array(sorted({tuple(sorted((int(a),int(b)))) for a,b,c in tri for a,b in [(a,b),(b,c),(c,a)]}),dtype=np.int32)

bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
standing=physical[0];lengths=np.linalg.norm(standing[edges[:,1]]-standing[edges[:,0]],axis=1)

def spring(points):
 for step in range(8):
  delta=points[edges[:,1]]-points[edges[:,0]];distance=np.linalg.norm(delta,axis=1)
  target=np.clip(distance,lengths*.35,lengths*2.0)
  shift=delta*((distance-target)/np.maximum(distance,1e-8)*.4)[:,None]
  change=np.zeros_like(points);count=np.zeros(len(points))
  np.add.at(change,edges[:,0],shift);np.add.at(change,edges[:,1],-shift)
  np.add.at(count,edges[:,0],1);np.add.at(count,edges[:,1],1)
  points+=change/np.maximum(count,1)[:,None]

fitted={}
for sample in range(0,121,4):
 frame=1+sample*.5;bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
 points=physical[sample].copy();initial=points.copy()
 skin=world_points(body);tree=VolumeSurface.FromPolygons(skin.tolist(),faces,all_triangles=True)
 def exterior_shift(point):
  p=Vector(point);near,normal,_,distance=tree.find_nearest(p)
  if distance<.001 or (near-p).dot(normal)<=0 or not inside_surface(tree,p):return None
  # Prefer the actual nearest outward boundary. At overlapping folds choose
  # the shortest exterior route rather than jumping through the other thigh.
  nearest=p+normal*(distance+.006)
  if not inside_surface(tree,nearest):return np.array(nearest-p)
  choices=[]
  for direction in [normal,Vector((0,0,-1)),Vector((0,-1,0)),Vector((0,1,0)),Vector((1,0,0)),Vector((-1,0,0))]:
   for travel in [distance+.006,.012,.024,.048,.096]:
    result=p+direction*travel
    if not inside_surface(tree,result):
     choices.append((travel,direction*travel));break
  if not choices:raise RuntimeError('No local exterior garment route at '+str(tuple(p)))
  return np.array(min(choices,key=lambda pair:pair[0])[1])
 for iteration in range(64):
  spring(points)
  changes=np.zeros_like(points);counts=np.zeros(len(points));hits=0
  for index,point in enumerate(points):
   shift=exterior_shift(point)
   if shift is not None:changes[index]+=shift;counts[index]+=1;hits+=1
  for face in tri:
   shift=exterior_shift(points[face].mean(axis=0))
   if shift is not None:
    changes[face]+=shift;counts[face]+=1;hits+=1
  points+=changes/np.maximum(counts,1)[:,None]
  maximum=np.linalg.norm(points-initial,axis=1).max()
  if maximum>.12:raise RuntimeError(f'Shared fabric exceeds120mm guard: sample{sample} {maximum:.6f}m')
  if hits==0:break
 key=cloth.data.shape_keys.key_blocks['Seat cloth %02d'%sample]
 for vertex,point in zip(cloth.data.vertices,points):
  blend=Matrix.Identity(4)*0;total=0
  for group in vertex.groups:
   bone=rig.pose.bones.get(cloth.vertex_groups[group.group].name)
   if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*group.weight;total+=group.weight
  transform=rig.matrix_world@(blend*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@cloth.matrix_world
  key.data[vertex.index].co=transform.inverted_safe()@Vector(point)
 fitted[sample]=[v.co.copy() for v in key.data]
 print('CLERK_SHARED_FIT',sample,'contacts',hits,'iterations',iteration+1,'max_mm',round(maximum*1000,3),flush=True)
for sample in range(121):
 left=sample//4*4;right=min(left+4,120);fraction=(sample-left)/4
 key=cloth.data.shape_keys.key_blocks['Seat cloth %02d'%sample]
 for vertex,a,b in zip(key.data,fitted[left],fitted[right]):vertex.co=a.lerp(b,fraction)
bpy.context.scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
sys.argv.extend(['--export-only','--source',str(OUTPUT),'--runtime',str(RUNTIME)])
runpy.run_path(str(ROOT/'tools/characters/refit_clerk_seat_layers.py'),run_name='__main__')
