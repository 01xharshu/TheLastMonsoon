"""Reuse the complete MPFB donor; build continuous clothing over its real skin."""
import bpy,bmesh,json,math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
from river_asset_export import export_river_asset
OUT=ROOT/'WorkingAssets/NPCs/river_woman';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/village_woman/village_woman_motion_candidate.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
retain_complete_body(body);rig.data.pose_position='REST';bpy.context.view_layer.update()
masks=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
for modifier,_ in masks:modifier.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
rest=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
for modifier,enabled in masks:modifier.show_viewport=enabled
basis=rig.matrix_world.inverted()@body.matrix_world
normal_basis=basis.to_3x3().inverted().transposed()
points=[basis@vertex.co for vertex in rest.vertices]
normals=[(normal_basis@vertex.normal).normalized() for vertex in rest.vertices]
rest.calc_loop_triangles()
body_group=body.vertex_groups['body'].index
human={vertex.index for vertex in body.data.vertices if any(group.group==body_group and group.weight>.5 for group in vertex.groups)}
weights={vertex.index:{body.vertex_groups[group.group].name:group.weight for group in vertex.groups if body.vertex_groups[group.group].name in rig.data.bones} for vertex in body.data.vertices if vertex.index in human}
names=['Fitted cotton upper base','Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']
for name in names:
 obj=bpy.data.objects.get(name)
 if obj:bpy.data.objects.remove(obj,do_unlink=True)
def material(name,color):
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
 shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=(*color,1);shader.inputs['Roughness'].default_value=.95
 return mat
sari=material('River plain woven cotton',(.31,.115,.105));upper_mat=material('River cotton blouse',(.30,.25,.11));border=material('River cotton border',(.43,.34,.22));under=material('Opaque adult foundation',(.30,.24,.17))
def surface(name,accepted,offset,mat):
 selected=[polygon for polygon in rest.polygons if all(index in human and accepted(index) for index in polygon.vertices)]
 ids=sorted({index for polygon in selected for index in polygon.vertices});mapping={index:i for i,index in enumerate(ids)}
 selected_ids={polygon.index for polygon in selected}
 mesh=bpy.data.meshes.new(name+' surface');mesh.from_pydata([points[index]+normals[index]*offset for index in ids],[],[tuple(mapping[index] for index in triangle.vertices) for triangle in rest.loop_triangles if triangle.polygon_index in selected_ids]);mesh.update()
 for polygon in mesh.polygons:polygon.use_smooth=True
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
 obj.modifiers.new('Original MPFB skin weights','ARMATURE').object=rig
 for index,source in enumerate(ids):
  for bone,weight in weights[source].items():
   (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([index],weight,'REPLACE')
 mesh.materials.append(mat);obj['body_source']='Complete original MPFB body; no covered skin removed'
 print('RIVER_GARMENT',name,'vertices',len(ids),'faces',len(selected),flush=True)
 return obj,len(selected)
def upper_accept(index):
 p=points[index];w=weights[index]
 torso=.815<p.z<1.27 and abs(p.x)<.215
 sleeve=False
 for side in ['l','r']:
  head=rig.data.bones['upperarm_'+side].head_local
  if w.get('upperarm_'+side,0)>.15 and (p-head).length<.18:sleeve=True
 return torso or sleeve
blouse,_=surface('Fitted cotton upper base',upper_accept,.024,upper_mat)
# Cloth bridges the chest instead of copying small skin details. The complete
# unchanged body remains beneath it; this affects only the garment surface.
from mathutils.kdtree import KDTree
tree=KDTree(len(points))
for i,p in enumerate(points):tree.insert(Vector((p.x,0,p.z)),i)
tree.balance()
for vertex in blouse.data.vertices:
 p=vertex.co
 if .98<p.z<1.18 and p.y<-.03:
  shoulder=min(1.0,max(0.0,(.20-abs(p.x))/.05))
  vertical=min(1.0,max(0.0,(p.z-.98)/.025),max(0.0,(1.18-p.z)/.025))
  p.y=min(p.y,p.y*(1-shoulder*vertical)-.19*shoulder*vertical)
def clip_surface(obj,plane_point,plane_normal,inner=True):
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=plane_point,plane_no=plane_normal,clear_inner=inner,clear_outer=not inner)
 bm.to_mesh(obj.data);bm.free();obj.data.update()
clip_surface(blouse,(0,0,1.245),(0,0,1),False)
def foundation_accept(index):
 x,y,z=points[index]
 return (.995<z<1.17 and abs(x)<.19) or (1.15<z<1.19 and .10<abs(x)<.14) or (.785<z<.825 and abs(x)<.19) or (.64<z<.825 and ((y<-.025 and abs(x)<.105) or (y>=-.025 and abs(x)<.035)))
_,foundation_faces=surface('Opaque fitted bra and thong foundation',foundation_accept,.014,under)
def pallu_accept(index):
 p=points[index]
 # A continuous diagonal skin-following cotton panel, outside the blouse.
 center=.14-(p.z-.85)/.39*.29
 return .84<p.z<1.27 and p.y<-.015 and abs(p.x-center)<.15 and abs(p.x)<.23
pallu,_=surface('Woven sari pallu over blouse',pallu_accept,.044,sari)
for vertex in pallu.data.vertices:
 p=vertex.co
 if .98<p.z<1.18 and p.y<-.03:
  shoulder=min(1.0,max(0.0,(.20-abs(p.x))/.05))
  vertical=min(1.0,max(0.0,(p.z-.98)/.025),max(0.0,(1.18-p.z)/.025))
  p.y=min(p.y,p.y*(1-shoulder*vertical)-.213*shoulder*vertical)
slope=.29/.39
clip_surface(pallu,(.14-.105,0,.85),(1,0,slope),True)
clip_surface(pallu,(.14+.105,0,.85),(1,0,slope),False)
clip_surface(pallu,(0,0,1.255),(0,0,1),False)
# Use a smooth woven shell rather than reproducing skin details in the outer
# blouse/pallu. Only clothing is rebuilt; every donor body vertex stays intact.
bpy.data.objects.remove(blouse,do_unlink=True);bpy.data.objects.remove(pallu,do_unlink=True)
profile=[(.815,.215,.165),(.94,.215,.165),(1.05,.21,.20),(1.14,.205,.18),(1.20,.215,.13),(1.245,.085,.075)]
def section(z):
 for a,b in zip(profile,profile[1:]):
  if a[0]<=z<=b[0]:
   t=(z-a[0])/(b[0]-a[0]);return a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2])
 return profile[-1][1:]
skin_tree=KDTree(len(human))
for index in human:skin_tree.insert(points[index],index)
skin_tree.balance()
def woven_shell(name,vertices,faces,mat):
 mesh=bpy.data.meshes.new(name+' smooth shell');mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(mat)
 for polygon in mesh.polygons:polygon.use_smooth=True
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
 obj.modifiers.new('Retained MPFB garment rig','ARMATURE').object=rig
 for i,p in enumerate(vertices):
  _,source,_=skin_tree.find(Vector(p))
  for bone,weight in weights[source].items():(obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([i],weight,'REPLACE')
 return obj
vertices=[];faces=[];N=48;R=32
for row in range(R+1):
 z=.815+(1.245-.815)*row/R;rx,ry=section(z)
 for col in range(N):
  angle=math.tau*col/N;vertices.append((rx*math.cos(angle),ry*math.sin(angle)-.008,z))
for row in range(R):
 for col in range(N):
  a=row*N+col;b=row*N+(col+1)%N;faces.extend([(a,b,a+N),(b,b+N,a+N)])
blouse=woven_shell('Fitted cotton upper base',vertices,faces,upper_mat)
# Existing skin-derived sleeve panels keep their exact shoulder/arm weighting.
def sleeve_accept(index):
 p=points[index];w=weights[index]
 return any(w.get('upperarm_'+side,0)>.15 and (p-rig.data.bones['upperarm_'+side].head_local).length<.18 for side in ['l','r'])
sleeves,_=surface('River blouse sleeves',sleeve_accept,.024,upper_mat)
bpy.ops.object.select_all(action='DESELECT');blouse.select_set(True);sleeves.select_set(True);bpy.context.view_layer.objects.active=blouse;bpy.ops.object.join()
vertices=[];faces=[];ROWS=32;COLS=8
for row in range(ROWS+1):
 z=.84+(1.24-.84)*row/ROWS;rx,ry=section(z);center=.14-(z-.85)/.39*.29
 for col in range(COLS+1):
  x=max(-rx*.98,min(rx*.98,center+(col/COLS-.5)*.19))
  y=-ry*math.sqrt(max(0,1-(x/rx)**2))-.026
  vertices.append((x,y,z))
for row in range(ROWS):
 for col in range(COLS):
  a=row*(COLS+1)+col;faces.extend([(a,a+COLS+1,a+1),(a+1,a+COLS+1,a+COLS+2)])
woven_shell('Woven sari pallu over blouse',vertices,faces,sari)
# Editable rest drape. The bounded runtime fabric follows actual leg positions.
RINGS=20;SEGMENTS=40;WAIST=.905
for name,low,high,mat in [('Wrapped sari lower drape',.020,WAIST,sari),('Sari lower border',.020,.050,border)]:
 rings=RINGS if name=='Wrapped sari lower drape' else 2;vertices=[];faces=[]
 for row in range(rings+1):
  t=row/rings;z=high+(low-high)*t
  for angle in range(SEGMENTS):
   theta=math.tau*angle/SEGMENTS;rx=.205+.055*t;ry=.165+.095*t
   pleat=.003*(1+math.cos(theta*10))
   vertices.append((math.cos(theta)*(rx+pleat),math.sin(theta)*(ry+pleat),z))
 for row in range(rings):
  for angle in range(SEGMENTS):
   a=row*SEGMENTS+angle;b=row*SEGMENTS+(angle+1)%SEGMENTS;c=b+SEGMENTS;d=a+SEGMENTS;faces.append((a,d,c,b))
 mesh=bpy.data.meshes.new(name+' continuous fabric');mesh.from_pydata(vertices,[],faces);mesh.update()
 for polygon in mesh.polygons:polygon.use_smooth=True
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
 obj.modifiers.new('Editable rest drape rig','ARMATURE').object=rig
 group=obj.vertex_groups.new(name='pelvis');group.add(list(range(len(vertices))),1,'REPLACE');mesh.materials.append(mat)
 obj['runtime_deformation']='Continuous bounded fabric envelope; original complete body retained'
def radius(bone,child):
 start=rig.data.bones[bone].head_local;end=rig.data.bones[child].head_local;axis=end-start
 values=[]
 for index,w in weights.items():
  if w.get(bone,0)>.5:
   point=points[index];t=max(0,min(1,(point-start).dot(axis)/axis.length_squared));values.append((point-(start+axis*t)).length)
 return max(values,default=.08)
metadata={'rings':RINGS,'segments':SEGMENTS,'waist_bone':'spine_01','waist_offset':WAIST-rig.data.bones['spine_01'].head_local.z,'waist_rx':.205,'waist_ry':.165,'hem_radius':.26,'pelvis_rx':.205,'pelvis_ry':.17,'pelvis_height':.14,'clearance':.018,'thigh_radius':max(radius('thigh_'+side,'calf_'+side) for side in ['l','r'])+.012,'calf_radius':max(radius('calf_'+side,'foot_'+side) for side in ['l','r'])+.012,'foot_radius':.065}
(OUT/'cloth_runtime.json').write_text(json.dumps(metadata,indent=2)+'\n')
(ROOT/'characters/npcs/indian/river_sari_dimensions.gd').write_text('extends RefCounted\n## Dimensions measured from the retained MPFB body.\nconst DATA := '+json.dumps(metadata)+'\n')
print('RIVER_CLOTH_RUNTIME',json.dumps(metadata),flush=True)
bpy.data.meshes.remove(rest);rig.data.pose_position='REST';bpy.context.view_layer.update()
export_river_asset(ROOT,rig,body,foundation_faces)
