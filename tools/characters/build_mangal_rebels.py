"""Clothing-only MPFB derivative; retain merchant body/foundation and original rig."""
import bpy,json,hashlib,struct
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'WorkingAssets/NPCs/households/merchant/merchant.blend'
donor=ROOT/'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
body=bpy.data.objects['village_farmer_MakeHuman_body']
def digest(obj):return hashlib.sha256(b''.join(struct.pack('<3f',*v.co) for v in obj.data.vertices)).hexdigest()
before=digest(body)
# Replace only outer dress. Eyes, hair, moustache, footwear, entire body and shorts stay.
for name in ['Bordered shoulder shawl','Fitted turban crown','Fitted turban fold 0','Fitted turban fold 1','Fitted turban fold 2']:
 bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
names=['Soft cotton head wrap','Head wrap fold']
with bpy.data.libraries.load(str(donor),link=False) as (available,loaded):
 assert all(n in available.objects for n in names),available.objects
 loaded.objects=names
bpy.context.view_layer.update()
verts=[body.matrix_world@v.co for v in body.data.vertices];tree=BVHTree.FromPolygons(verts,[list(p.vertices) for p in body.data.polygons])
shirt=bpy.data.objects['Fitted cotton upper base']
shirt_tree=BVHTree.FromPolygons([shirt.matrix_world@v.co for v in shirt.data.vertices],[list(p.vertices) for p in shirt.data.polygons])
def cotton(name,color):
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.94
 return mat
rust=cotton('Rebel madder cotton kurta',(.30,.065,.035));indigo=cotton('Rebel indigo headcloth and dhoti',(.035,.085,.12));edge=cotton('Rebel undyed woven edging',(.64,.51,.32))
shirt=bpy.data.objects['Fitted cotton upper base'];shirt.data.materials.clear();shirt.data.materials.append(rust)
for obj in loaded.objects:
 bpy.context.collection.objects.link(obj)
 for mod in list(obj.modifiers):
  if mod.type=='ARMATURE':mod.object=rig
  if mod.type=='MASK':obj.modifiers.remove(mod)
 world=obj.matrix_world.copy();obj.parent=rig;obj.matrix_world=world
 obj.data.materials.clear();obj.data.materials.append(indigo if 'wrap' in obj.name.lower() else edge if 'fold' in obj.name.lower() else rust)
 for v in obj.data.vertices:
  at=obj.matrix_world@v.co;point,normal,face,distance=tree.find_nearest(at)
  if face is not None and distance<.12:
   clearance=(at-point).dot(normal)
   if clearance<.018:v.co=obj.matrix_world.inverted()@(at+normal*(.018-clearance))
 obj['provenance']='Existing MPFB farmer clothing only; rebound to original merchant rig; 18mm rest clearance'
# Author a fitted woven waist sash, rather than donor's pointed lower tails.
# Its skin weights interpolate the original complete body surface at each row.
import math
vertices=[];faces=[];N=48;ROWS=6
for row in range(ROWS):
 t=row/(ROWS-1);z=.98-.09*t
 for i in range(N):
  angle=2*math.pi*i/N
  vertices.append(((.24+.005*t)*math.cos(angle),.012+(.17+.01*t)*math.sin(angle),z))
for row in range(ROWS-1):
 for i in range(N):
  a=row*N+i;b=row*N+(i+1)%N;faces.append((a,a+N,b+N,b))
mesh=bpy.data.meshes.new('Rebel woven waist sash');mesh.from_pydata(vertices,[],faces);mesh.materials.append(edge)
hem=bpy.data.objects.new('Rebel woven waist sash',mesh);bpy.context.collection.objects.link(hem);hem.parent=rig
for group in body.vertex_groups:hem.vertex_groups.new(name=group.name)
for v in mesh.vertices:
 shirt_point,shirt_normal,_,_=shirt_tree.find_nearest(v.co)
 v.co=shirt_point+shirt_normal*.009
 point,normal,face,distance=tree.find_nearest(v.co)
 nearby=list(body.data.polygons[face].vertices)
 factors={i:1/max((verts[i]-point).length_squared,.000001) for i in nearby};total=sum(factors.values())
 weights={}
 for i,factor in factors.items():
  for group in body.data.vertices[i].groups:weights[group.group]=weights.get(group.group,0)+group.weight*factor/total
 # Keep a waist garment on the torso; nearby wrists must not pull it apart.
 weights={index:weight for index,weight in weights.items() if body.vertex_groups[index].name in ['pelvis','spine_01','spine_02']}
 total=sum(weights.values())
 if total<.001:weights={body.vertex_groups['pelvis'].index:1.0};total=1.0
 for index,weight in weights.items():
  if weight>.00001:hem.vertex_groups[index].add([v.index],weight/total,'REPLACE')
 clearance=(v.co-point).dot(normal)
 if clearance<.022:v.co+=normal*(.022-clearance)
for face in mesh.polygons:face.use_smooth=True
mod=hem.modifiers.new('Original MPFB skin','ARMATURE');mod.object=rig
solid=hem.modifiers.new('Cotton thickness','SOLIDIFY');solid.thickness=.002
for name,mat in [('Knee length wrapped dhoti',indigo),('Dhoti woven border',edge)]:
 obj=bpy.data.objects[name];obj.data.materials.clear();obj.data.materials.append(mat)
# Tailored knee breeches use the unchanged MPFB fitting surface and its exact
# skin weights. A connected crotch follows the seated thighs without the open
# skirt's rear split exposing the foundation. Retain separate hem/waist edging.
for name in ['Knee length wrapped dhoti','Dhoti woven border']:
 bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
allowed={'pelvis','thigh_l','thigh_r','lowerleg_l','lowerleg_r'}
selected=[]
for poly in body.data.polygons:
 points=[body.data.vertices[i] for i in poly.vertices]
 if all(.43<v.co.z<.97 and sum(g.weight for g in v.groups if body.vertex_groups[g.group].name in allowed)>.6 for v in points):selected.append(poly)
indices=sorted({i for poly in selected for i in poly.vertices});mapping={old:new for new,old in enumerate(indices)}
coords=[]
for i in indices:
 v=body.data.vertices[i];normal=v.normal.copy()
 coords.append(v.co+normal*.027)
cloth=bpy.data.meshes.new('Indigo tailored knee breeches fabric')
cloth.from_pydata(coords,[],[[mapping[i] for i in poly.vertices] for poly in selected]);cloth.materials.append(indigo);cloth.materials.append(edge)
pants=bpy.data.objects.new('Indigo tailored knee breeches',cloth);bpy.context.collection.objects.link(pants);pants.parent=rig
for group in body.vertex_groups:pants.vertex_groups.new(name=group.name)
for old,new in mapping.items():
 for group in body.data.vertices[old].groups:pants.vertex_groups[group.group].add([new],group.weight,'REPLACE')
for poly in cloth.polygons:
 poly.use_smooth=True
 if min(cloth.vertices[i].co.z for i in poly.vertices)<.47:poly.material_index=1
arm=pants.modifiers.new('Original MPFB fabric skin','ARMATURE');arm.object=rig
solid=pants.modifiers.new('Woven cotton thickness','SOLIDIFY');solid.thickness=.002
pants['provenance']='Tailored garment fitted over original complete MPFB body; exact original skin weights; 27mm rest allowance; connected crotch and knee hems'
assert digest(body)==before
out=ROOT/'WorkingAssets/NPCs/mangal_rebels';out.mkdir(parents=True,exist_ok=True)
runtime=ROOT/'characters/npcs/mangal_rebels';runtime.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'mangal_rebel.blend'))
bpy.ops.export_scene.gltf(filepath=str(runtime/'mangal_rebel.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
(out/'manifest.json').write_text(json.dumps({'body_source':str(source.relative_to(ROOT)),'clothing_donor':str(donor.relative_to(ROOT)),'rebuild':'Blender --background --python tools/characters/build_mangal_rebels.py','body_vertex_sha256':before,'body_vertices':len(body.data.vertices),'foundation_retained':True,'style':'madder cotton tunic, indigo tailored knee breeches/headcloth, undyed woven waist sash and edging','status':'rest-fitted candidate; native motion and clothing acceptance pending'},indent=2)+'\n')
print('MANGAL_REBEL_BODY_UNCHANGED',before,len(body.data.vertices))
