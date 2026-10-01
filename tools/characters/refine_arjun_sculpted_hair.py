"""Reference-directed flattened wave locks; separate MPFB-compatible candidate."""
import bpy,math,random,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_projected_drape_candidate.blend'
OUT=ROOT/'docs/characters/arjun/reference_fit/sculpted_hair_2026-10-01';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig=bpy.data.objects['Arjun_Rig'];mat=bpy.data.materials['Arjun black wavy locks']
bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Roughness'].default_value=.84;bs.inputs['Specular IOR Level'].default_value=.12
for name in ['Arjun_Reference_WavyCrown','Arjun_Reference_WavyLocks']:
 obj=bpy.data.objects.get(name)
 if obj:obj.hide_render=True

def low(a):return -.22-.42*math.sin(a)
def position(a,e):
 c=math.cos(e);wave=.003*math.sin(a*9+e*7)*max(0,c)**.6
 y_radius=.105-.013*math.sin(a)
 quiff=.021*math.exp(-((math.atan2(math.sin(a+math.pi/2),math.cos(a+math.pi/2)))/.9)**2)*math.sin(2*e)**2
 return Vector(((.111+wave)*math.cos(a)*c,-.020+(y_radius+wave)*math.sin(a)*c,1.626+(.139+wave)*math.sin(e)+quiff))

def mesh(name,verts,faces):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update();obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj);data.materials.append(mat)
 for p in data.polygons:p.use_smooth=True
 group=obj.vertex_groups.new(name='head');group.add(list(range(len(verts))),1,'REPLACE');obj.parent=rig;mod=obj.modifiers.new('Head skin','ARMATURE');mod.object=rig
 return obj
verts=[];faces=[]
for j in range(65):
 for i in range(160):
  a=math.tau*i/160;e=low(a)+(math.pi/2-low(a))*j/64;verts.append(tuple(position(a,e)))
for j in range(64):
 for i in range(160):
  n=(i+1)%160;faces.append((j*160+i,j*160+n,(j+1)*160+n,(j+1)*160+i))
mesh('Arjun_SculptedCrown',verts,faces)
# Closed flattened locks: wide cross section, thin radial depth, tapered ends.
random.seed(34);verts=[];faces=[]
for lock in range(480):
 a=random.uniform(0,math.tau);e=random.uniform(low(a)+.02,1.47);length=random.uniform(.30,.66);width=random.uniform(.002,.004);sweep=random.uniform(-.16,.16)
 base=len(verts)
 for j in range(25):
  t=j/24;az=a+(t-.5)*length
  el=max(low(az)+.01,min(1.55,e+sweep*(t-.5)+.055*math.sin(t*math.pi*1.4)))
  p=position(az,el);normal=(p-Vector((0,-.02,1.626))).normalized()
  tangent=(position(az+.001,el)-position(az-.001,el)).normalized();across=normal.cross(tangent).normalized()
  taper=.05+.95*math.sin(math.pi*t)**.6
  lift=.0005+.003*math.sin(math.pi*t)
  for k in range(8):
   theta=math.tau*k/8
   q=p+normal*(lift+.0011*taper*math.sin(theta))+across*(width*taper*math.cos(theta))
   verts.append(tuple(q))
 for j in range(24):
  for k in range(8):
   n=(k+1)%8;faces.append((base+j*8+k,base+j*8+n,base+(j+1)*8+n,base+(j+1)*8+k))
 faces.append(tuple(base+k for k in reversed(range(8))));faces.append(tuple(base+24*8+k for k in range(8)))
mesh('Arjun_FlattenedWaveLocks',verts,faces)
scene=bpy.context.scene;camera=scene.camera;scene.cycles.samples=24
camera.location=(0,-4,.88);camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_sculpted_hair_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 camera.location=pos;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','source':str(SOURCE.relative_to(ROOT)),'candidate':str(candidate.relative_to(ROOT)),'locks':480,'exact_match':False,'runtime_replaced':False},indent=2)+'\n')
