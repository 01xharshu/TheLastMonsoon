"""Construct a close back panel from the candidate's fitted blouse and weights."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
blouse=bpy.data.objects['Street coherent cotton blouse and pallu'];old=bpy.data.objects['Street sari back tail']
blouse.data.calc_loop_triangles();triangles=[]
for tri in blouse.data.loop_triangles:
 p=sum((blouse.matrix_world@blouse.data.vertices[i].co for i in tri.vertices),Vector())/3
 if .84<p.z<1.24 and p.y>.005 and -.22<p.x<.035:triangles.append(tuple(tri.vertices))
if len(triangles)<30:raise RuntimeError('Back panel selection is unexpectedly small')
ids=sorted({i for tri in triangles for i in tri});index={old_index:new_index for new_index,old_index in enumerate(ids)}
normals=[Vector() for _ in blouse.data.vertices]
for tri in blouse.data.loop_triangles:
 a,b,c=[blouse.data.vertices[i].co for i in tri.vertices];normal=(b-a).cross(c-a)
 for i in tri.vertices:normals[i]+=normal
points=[]
for i in ids:
 normal=normals[i].normalized()
 if normal.y<0:normal=-normal
 points.append(blouse.data.vertices[i].co+normal*.018)
mesh=bpy.data.meshes.new('Supported back cotton panel');mesh.from_pydata(points,[],[tuple(index[i] for i in tri) for tri in triangles]);mesh.update();mesh.materials.append(old.data.materials[0])
panel=bpy.data.objects.new('Street sari back tail supported',mesh);bpy.context.collection.objects.link(panel)
panel.parent=blouse.parent;panel.matrix_parent_inverse=blouse.matrix_parent_inverse.copy();panel.matrix_basis=blouse.matrix_basis.copy()
for group in blouse.vertex_groups:panel.vertex_groups.new(name=group.name)
for j,i in enumerate(ids):
 for g in blouse.data.vertices[i].groups:panel.vertex_groups[g.group].add([j],g.weight,'REPLACE')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');panel.modifiers.new('Original MPFB rig','ARMATURE').object=rig
for face in mesh.polygons:face.use_smooth=True
old.name='Previous sari back tail source';old['street_source_only']=True;old.hide_render=True;old.hide_set(True)
panel.name='Street sari back tail';panel['construction']='18mm outer patch of fitted blouse with identical skin weights'
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('SUPPORTED_SARI_TAIL',slug,'faces',len(triangles),'vertices',len(ids),flush=True)
