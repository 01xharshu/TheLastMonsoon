"""Editable first-reference costume fitted to Leela's current facial/body source."""
import bpy, math, json, hashlib, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from fit_leela_face import shaped_coordinates
OUT=ROOT/'WorkingAssets/NPCs/leela/costume_study';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/leela/body_study/leela_body_study.blend'))
bpy.context.preferences.filepaths.save_version=0
body=bpy.data.objects['Leela_independent_body_study'];rig=bpy.data.objects['Leela_body_study_game_engine_rig']
for p in rig.pose.bones:p.rotation_mode='XYZ';p.rotation_euler=(0,0,0)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
DATA=Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data'
def mat(name,col,rough=.8):
 m=bpy.data.materials.new(name);m.use_fake_user=True;m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough
 noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1100
 coord=m.node_tree.nodes.new('ShaderNodeTexCoord');m.node_tree.links.new(coord.outputs['Object'],noise.inputs['Vector'])
 variation=m.node_tree.nodes.new('ShaderNodeTexNoise');variation.inputs['Scale'].default_value=32;m.node_tree.links.new(coord.outputs['Object'],variation.inputs['Vector'])
 ramp=m.node_tree.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*(c*.78 for c in col),1);ramp.color_ramp.elements[1].color=(*(c*1.16 for c in col),1)
 m.node_tree.links.new(variation.outputs['Fac'],ramp.inputs['Fac']);m.node_tree.links.new(ramp.outputs['Color'],p.inputs['Base Color'])
 if 'leather' not in name:p.inputs['Sheen Weight'].default_value=.18
 bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.19;bump.inputs['Distance'].default_value=.00018
 m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal']);return m
green=mat('Leela forest green woven cotton',(.035,.075,.059));red=mat('Leela faded rust-red drape',(.24,.043,.029));cream=mat('Leela unbleached gathered cotton',(.63,.54,.40));leather=mat('Leela worn brown leather',(.075,.034,.017),.65);gold=mat('Leela muted copper thread',(.33,.18,.065),.6)
def mesh(name,vs,fs,m,sub=1):
 d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.materials.append(m);o=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(o)
 for p in d.polygons:p.use_smooth=True
 if sub:s=o.modifiers.new('Smooth fabric','SUBSURF');s.levels=sub
 s=o.modifiers.new('Fabric thickness','SOLIDIFY');s.thickness=.002
 return o
def thread(name,points,m,radius=.001):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=radius;d.bevel_resolution=2
 c=d.splines.new('POLY');c.points.add(len(points)-1)
 for v,co in zip(c.points,points):v.co=(*co,1)
 o=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(o);d.materials.append(m);return o

def tube(name,levels,m,n=64,fold=.003):
 dense=[]
 for a,b in zip(levels,levels[1:]):
  for j in range(6):dense.append(tuple(x+(y-x)*j/6 for x,y in zip(a,b)))
 dense.append(levels[-1]);levels=dense
 vs=[]
 for j,(z,rx,ry,cx,cy) in enumerate(levels):
  for i in range(n):
   a=i*math.tau/n;envelope=math.sin(math.pi*j/(len(levels)-1))**.5
   if 'gathered trousers' in name:
    envelope*=max(0,min(1,(z-.36)/.10))
    if z<.35:rx=min(rx,.051);ry=min(ry,.052)
   f=fold*envelope*(.6*math.sin(a*11+z*36)+.25*math.sin(a*17-z*58)+.18*math.sin(z*145+a*3));vs.append((cx+(rx+f)*math.cos(a),cy+(ry+f)*math.sin(a),z))
 fs=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(levels)-1) for i in range(n)]
 return mesh(name,vs,fs,m)
# Native fitted blouse keeps the current bust shape and sleeve topology.
a=HumanService.add_mhclo_asset(str(DATA/'clothes/female_casualsuit01/female_casualsuit01.mhclo'),body,asset_type='Clothes',subdiv_levels=1)
bodice=a
a.name='Leela fitted tunic bodice and sleeves';a.data.materials.clear();a.data.materials.append(green)
for p in a.data.polygons:p.material_index=0
# Connected components isolate the upper garment.
parent=list(range(len(a.data.vertices)))
def find(i):
 while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
 return i
for e in a.data.edges:parent[find(e.vertices[0])]=find(e.vertices[1])
comps={}
for v in a.data.vertices:comps.setdefault(find(v.index),[]).append(v.index)
upper=max(comps.values(),key=lambda ids:max(a.data.vertices[i].co.z for i in ids))
g=a.vertex_groups.new(name='Costume upper component');g.add(upper,1,'REPLACE');md=a.modifiers.new('Upper garment only','MASK');md.vertex_group=g.name
# Extend the short native sleeve to the reference's rolled forearm length.
def arm_tube(name,start,end,radii,material):
 start,end=Vector(start),Vector(end);axis=(end-start).normalized();u=Vector((0,1,0));v=axis.cross(u).normalized()
 vs=[];n=48
 for j,r in enumerate(radii):
  t=j/(len(radii)-1);center=start.lerp(end,t)
  for i in range(n):
   angle=i*math.tau/n;fold=.0028*math.sin(angle*7+t*15)+.0013*math.sin(t*40+angle*2)
   vs.append(tuple(center+(r+fold)*(u*math.cos(angle)+v*math.sin(angle))))
 return mesh(name,vs,[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(radii)-1) for i in range(n)],material)
points=shaped_coordinates(body)
body_group=body.vertex_groups.get('body')
actual={v.index for v in body.data.vertices if any(g.group==body_group.index for g in v.groups)}
def sleeve_center(x):
 sample=[Vector(points[i]) for i in actual if abs(points[i][0]-x)<.009 and .88<points[i][2]<1.23]
 return sum(sample,Vector())/len(sample)
for sign,label in [(1,'left'),(-1,'right')]:
 start=sleeve_center(sign*.223);end=sleeve_center(sign*.345);direction=(end-start).normalized()
 arm_tube('Leela '+label+' extended sleeve',start,end,[.055,.052,.048,.044,.041],green)
 arm_tube('Leela '+label+' rolled cuff',end-direction*.018,end+direction*.008,[.043,.046,.045,.043],green)
 arm_tube('Leela '+label+' cuff copper seam',end+direction*.002,end+direction*.006,[.044,.044,.044],gold)
# Narrow central front opening and sewn placket, fitted to the bodice depth.
thread('Leela tunic front placket',[(-.023,-.103,1.23),(-.020,-.121,1.21),(-.013,-.139,1.18),(0,-.153,1.15),(.013,-.139,1.18),(.020,-.121,1.21),(.023,-.103,1.23)],gold,.0015)
# Body dimensions from evaluated shape keys, not the unshaped base mesh.
p=shaped_coordinates(body);print('BODY_BOUNDS',p.min(axis=0),p.max(axis=0))
# Tunic panels: uneven points, flared folds and two open side splits.
levels=[(.98,.158,.121),(.93,.205,.145),(.85,.248,.158),(.76,.263,.178),(.65,.27,.19)]
for sign,label in [(1,'front'),(-1,'back')]:
 vs=[];n=48
 for j,(z,rx,ry) in enumerate(levels):
  for i in range(n+1):
   t=i/n;a=math.pi*t;f=.010*(math.sin(a*10+j*.8)+.3*math.sin(a*17-j*.6))*j/4
   hem=(-.095*abs(math.cos(a))+.025*math.cos(a*3)) if j==4 else 0
   vs.append((rx*math.cos(a),sign*(ry+f)*math.sin(a),z+hem))
 fs=[(j*(n+1)+i,j*(n+1)+i+1,(j+1)*(n+1)+i+1,(j+1)*(n+1)+i) for j in range(4) for i in range(n)]
 mesh('Leela '+label+' split tunic panel',vs,fs,green)
 # Border follows actual hem rather than a circular hoop.
 border=[]
 for i in range(n+1):
  x,y,z=vs[4*(n+1)+i];border.extend([(x,y+sign*.002,z+.008),(x,y+sign*.002,z+.024)])
 mesh('Leela '+label+' copper hem border',border,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(n)],gold)
for sign,label in [(1,'left'),(-1,'right')]:
 tube('Leela '+label+' gathered trousers',[(.91,.08,.10,sign*.097,0),(.83,.102,.106,sign*.105,0),(.72,.13,.124,sign*.11,0),(.58,.112,.102,sign*.116,0),(.46,.10,.086,sign*.123,0),(.35,.082,.075,sign*.126,0),(.25,.058,.059,sign*.129,0),(.22,.054,.057,sign*.13,0)],cream,fold=.010)
 # Fitted boots use the native footwear rather than spherical toes.
shoes=HumanService.add_mhclo_asset(str(DATA/'clothes/shoes03/shoes03.mhclo'),body,asset_type='Clothes',subdiv_levels=1)
shoes.name='Leela fitted leather footwear';shoes.data.materials.clear();shoes.data.materials.append(leather)
for p in shoes.data.polygons:p.material_index=0
for sign,label in [(1,'left'),(-1,'right')]:
 tube('Leela '+label+' boot shaft',[(.08,.055,.063,sign*.13,.01),(.14,.055,.059,sign*.13,.008),(.22,.059,.060,sign*.13,.003),(.33,.078,.079,sign*.129,0)],leather,fold=.001)
 for z in [.12,.17,.23,.32]:
  r=.080 if z>.3 else .064
  tube('Leela '+label+' boot strap',[(z,r,r+.001,sign*.13,0),(z+.009,r,r+.001,sign*.13,0)],leather,fold=0)
bpy.context.view_layer.update()
blouse_tree=BVHTree.FromObject(bodice,bpy.context.evaluated_depsgraph_get())
def drape_point(x,y,z,front):
 origin=Vector((x,-1 if front else 1,z));direction=Vector((0,1 if front else -1,0))
 hit,normal,index,distance=blouse_tree.ray_cast(origin,direction,2)
 if hit is not None:y=hit.y+(-.007 if front else .007)+.0015*math.sin(x*280+z*40)
 elif z>1.20:
  top,normal,index,distance=blouse_tree.ray_cast(Vector((x,y,1.5)),Vector((0,0,-1)),1)
  if top is not None:z=top.z+.007
 return (x,y,z)
def smooth_path(points):
 result=[]
 for i in range(len(points)-1):
  a=Vector(points[max(0,i-1)]);b=Vector(points[i]);c=Vector(points[i+1]);d=Vector(points[min(len(points)-1,i+2)])
  for j in range(6):
   t=j/6;result.append(tuple(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
 return result+[points[-1]]
# Draped shoulder scarf follows bust and shoulder surface; pleats run along its length.
path=[(-.145,.065,1.25),(-.16,.025,1.265),(-.163,-.04,1.26),(-.163,-.11,1.255),(-.15,-.163,1.23),(-.12,-.174,1.16),(-.065,-.153,1.08),(.025,-.133,1.02),(.10,-.112,.99)]
path=smooth_path(path)
vs=[];n=16
for j,(x,y,z) in enumerate(path):
 for i in range(n+1):
  t=i/n-.5;vs.append(drape_point(x+t*.13,y-.009*math.cos(t*math.tau*4),z+.005*math.sin(t*math.tau*3),True))
front_drape_vertices=vs.copy()
mesh('Leela pleated shoulder drape',vs,[(j*(n+1)+i,j*(n+1)+i+1,(j+1)*(n+1)+i+1,(j+1)*(n+1)+i) for j in range(len(path)-1) for i in range(n)],red)
path=[(-.145,.07,1.25),(-.15,.13,1.23),(-.17,.147,1.12),(-.17,.145,1.0),(-.18,.18,.88),(-.18,.205,.74),(-.18,.205,.59)]
path=smooth_path(path)
vs=[]
for j,(x,y,z) in enumerate(path):
 for i in range(n+1):
  t=i/n-.5;vs.append(drape_point(x+t*.15,y+.008*math.cos(t*math.tau*4+j*.3),z,False))
back_drape_vertices=vs.copy()
mesh('Leela back drape tail',vs,[(j*(n+1)+i,j*(n+1)+i+1,(j+1)*(n+1)+i+1,(j+1)*(n+1)+i) for j in range(len(path)-1) for i in range(n)],red)
# Woven scarf borders follow each mesh edge; fine fringe hangs off the tail.
for label,vertices in [('front',front_drape_vertices),('back',back_drape_vertices)]:
 for edge in [0,n]:
  thread('Leela '+label+' drape border',[tuple(Vector(vertices[j*(n+1)+edge])+Vector((0,-.001 if label=='front' else .001,0))) for j in range(len(vertices)//(n+1))],gold,.0014)
for i in range(n+1):
 x,y,z=back_drape_vertices[-(n+1)+i]
 thread('Leela scarf fringe',[(x,y,z),(x+.002*math.sin(i),y+.003,z-.025-.004*math.sin(i*2))],red,.001)
tube('Leela rust waist wrap',[(.945,.176,.135,0,0),(.96,.176,.135,0,0),(.985,.171,.133,0,0),(1.0,.167,.13,0,0)],red,fold=.002)
for z in [.955,.978]:tube('Leela leather waist strap',[(z,.181,.141,0,0),(z+.013,.179,.139,0,0)],leather,fold=0)
# Sparse copper sprigs and diamond stitching follow the flared front panel.
for z,rx,ry in [(.70,.265,.19),(.76,.263,.178),(.82,.254,.166),(.88,.23,.154)]:
 for x in [-.19,-.12,-.055,.055,.12,.19]:
  if abs(x)>rx*.86:continue
  y=-ry*math.sqrt(1-(x/rx)**2)-.004
  thread('Leela embroidered stem',[(x,y,z),(x+.002,y-.001,z+.028)],gold,.0007)
  for dz,sg in [(.007,-1),(.015,1),(.022,-1)]:
   thread('Leela embroidered leaf',[(x,y-.001,z+dz),(x+sg*.006,y-.002,z+dz+.004),(x+sg*.003,y-.002,z+dz+.006),(x,y-.001,z+dz)],gold,.00065)
# Waist buckle and hanging pouch are separate editable objects.
bpy.ops.mesh.primitive_torus_add(major_radius=.018,minor_radius=.0025,location=(-.07,-.153,.974),rotation=(math.pi/2,0,0))
bpy.context.object.name='Leela brass waist buckle';bpy.context.object.data.materials.append(gold)
bpy.ops.mesh.primitive_cube_add(size=1,location=(.19,-.115,.91));o=bpy.context.object;o.name='Leela belt pouch';o.scale=(.060,.025,.075);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(leather);b=o.modifiers.new('Rounded pouch seams','BEVEL');b.width=.01;b.segments=3
for o in bpy.data.objects:
 if o.type=='CURVE' and o.name.startswith('Leela tunic front placket'):
  for pt in o.data.splines[0].points:
   x,y,z,w=pt.co;hit,normal,index,distance=blouse_tree.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2)
   if hit is not None:pt.co=(x,hit.y-.002,z,w)
# Disable mhclo deletion masks so source skin visibility is controlled deliberately.
for mod in body.modifiers:
 if mod.name.startswith('Delete.'):mod.show_render=False;mod.show_viewport=False
# Cover torso and legs inside garments without hiding the neckline or hands.
group=body.vertex_groups.new(name='Costume exposed skin');ids=[i for i,v in enumerate(shaped_coordinates(body)) if v[2]>1.22 or abs(v[0])>.22];group.add(ids,1,'REPLACE')
m=body.modifiers.new('Hide covered body','MASK');m.vertex_group=group.name
m.show_viewport=False;m.show_render=False
scene=bpy.context.scene;scene.view_layers[0].material_override=None;scene.cycles.samples=48
scene.render.resolution_x=800;scene.render.resolution_y=1000
cam=scene.camera;cam.data.ortho_scale=1.95
for name,loc in [('front',(0,-3,.98)),('three_quarter',(2,-3,.98)),('back',(0,3,.98)),('side',(3,0,.98))]:
 cam.location=loc;cam.rotation_euler=(Vector((0,0,.83))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.file.pack_all();source=OUT/'leela_costume_study.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
(OUT/'manifest.json').write_text(json.dumps({'status':'COSTUME_FITTING_VISUAL_REVIEW_OPEN','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'body_source':'body_study/leela_body_study.blend','direction':'first reference: green tunic, rust drape, cream trousers, brown boots','in_world':False,'limitations':'Procedural fabric draft; skirt/drape/trousers not skinned for motion. Hair and facial likeness open.'},indent=2)+'\n')
