"""Original female zebu-type candidate; no third-party geometry or textures."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/harshmishra/Documents/GitHub/TheLastMonsoon')
OUT=ROOT/'assets/animals/cow/household_cow.glb'
WORK=ROOT/'WorkingAssets/Animals/household_cow'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def point(p):return Vector((p[0],-p[2],p[1]))
def mat(name,color,rough=.72):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=rough
 return m
coat=mat('Original warm grey coat',(.69,.66,.58));dark=mat('Dark muzzle and cloven hooves',(.10,.08,.065));horn=mat('Horn keratin',(.39,.34,.25));eye=mat('Dark wet eye',(.022,.016,.010),.20);pink=mat('Udder skin',(.56,.40,.31));inside=mat('Ear inner skin',(.48,.39,.30))
parts=[];extras=[]
def ellipsoid(name,p,size,material=coat,group='Body',skin=True):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=point(p));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(material)
 for f in o.data.polygons:f.use_smooth=True
 (parts if skin else extras).append((o,group));return o
def segment(name,a,b,r1,r2,material=coat,group='Body',skin=True):
 pa,pb=point(a),point(b);axis=pb-pa
 bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=r1,radius2=r2,depth=axis.length,location=(pa+pb)*.5)
 o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(axis);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.data.materials.append(material)
 for f in o.data.polygons:f.use_smooth=True
 (parts if skin else extras).append((o,group));return o
ellipsoid('Barrel',(0,1.11,.06),(.39,.42,.89))
ellipsoid('Shoulder',(0,1.18,-.56),(.30,.34,.37))
ellipsoid('Hind quarter',(0,1.13,.62),(.33,.37,.34))
ellipsoid('Moderate female hump',(0,1.43,-.55),(.19,.15,.28))
ellipsoid('Neck',(0,1.14,-.93),(.22,.36,.33))
ellipsoid('Head',(0,1.10,-1.27),(.16,.28,.26),group='Head')
ellipsoid('Nasal bridge',(0,.97,-1.45),(.135,.17,.21),group='Head')
ellipsoid('Muzzle',(0,.89,-1.59),(.16,.105,.13),dark,'Head',False)
# Thin continuous loose skin beneath the neck rather than a second barrel.
ellipsoid('Dewlap',(0,.85,-.93),(.07,.27,.37))
for side in [-1,1]:
 tag='L' if side<0 else 'R';x=side*.27
 for end,z in [('Front',-.60),('Hind',.62)]:
  upper=(x,1.15,z);knee=(x,.59,z+(.09 if end=='Hind' else -.015));fetlock=(x,.085,z-.04)
  segment(end+' thigh '+tag,upper,knee,.10,.065,group=end+'Upper.'+tag)
  ellipsoid(end+' joint '+tag,knee,(.068,.08,.069),group=end+'Lower.'+tag)
  segment(end+' lower '+tag,knee,fetlock,.055,.036,group=end+'Lower.'+tag)
  for split in [-1,1]:
   ellipsoid('Cloven hoof '+end+tag+str(split),(x+split*.027,.064,z-.085),(.026,.057,.085),dark,end+'Lower.'+tag,False)
 # Small tapered female horns, distinct from ears and hump.
 base=(side*.105,1.34,-1.27);mid=(side*.14,1.47,-1.23);tip=(side*.17,1.59,-1.28)
 segment('Horn base '+tag,base,mid,.036,.021,horn,'Head',False)
 segment('Horn tip '+tag,mid,tip,.021,.002,horn,'Head',False)
 # Long leaf-like ears with a recessed inner surface.
 ear=ellipsoid('Ear '+tag,(side*.245,1.23,-1.245),(.16,.035,.08),coat,'Ear.'+tag,False)
 ear.rotation_euler[1]=side*.18
 ellipsoid('Ear inner '+tag,(side*.25,1.24,-1.27),(.13,.017,.058),inside,'Ear.'+tag,False)
 ellipsoid('Eye '+tag,(side*.149,1.18,-1.385),(.018,.023,.025),eye,'Head',False)
 ellipsoid('Nostril '+tag,(side*.105,.917,-1.68),(.024,.014,.008),eye,'Head',False)
ellipsoid('Udder',(0,.745,.57),(.16,.15,.20),pink,'Body',False)
for x in [-.07,.07]:
 for z in [.49,.64]:segment('Teat',(x,.68,z),(x,.60,z),.021,.013,pink,'Body',False)
segment('Tail skin',(0,1.28,.90),(0,.41,1.02),.030,.013,coat,'Tail',False)
ellipsoid('Tail switch',(0,.27,1.04),(.035,.16,.038),dark,'Tail',False)
# Weld the original body forms into one continuous skin. Preserve appendages.
bpy.ops.object.select_all(action='DESELECT')
for o,_ in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0][0];bpy.ops.object.join();body=bpy.context.object;body.name='Continuous cow skin'
remesh=body.modifiers.new('Welded original anatomy','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.020;remesh.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=body.modifiers.new('Surface relaxation','SMOOTH');smooth.factor=.7;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
dec=body.modifiers.new('Game skin budget','DECIMATE');dec.ratio=.60;bpy.ops.object.modifier_apply(modifier=dec.name)
for face in body.data.polygons:face.use_smooth=True
# Native rig and explicit source-authored weights.
bpy.ops.object.armature_add(location=(0,0,0));rig=bpy.context.object;rig.name='HouseholdCowRig';bpy.ops.object.mode_set(mode='EDIT');eb=rig.data.edit_bones;eb.remove(eb[0]);bones={}
def bone(name,a,b,parent=None):
 v=eb.new(name);v.head=point(a);v.tail=point(b)
 if parent:v.parent=bones[parent]
 bones[name]=v
bone('Body',(0,1.10,.65),(0,1.10,-.6))
bone('Head',(0,1.14,-.92),(0,1.03,-1.55),'Body')
bone('Tail',(0,1.28,.90),(0,.4,1.02),'Body')
for side in [-1,1]:
 tag='L' if side<0 else 'R';x=side*.27
 bone('Ear.'+tag,(side*.16,1.23,-1.25),(side*.37,1.23,-1.25),'Head')
 for end,z in [('Front',-.60),('Hind',.62)]:
  knee=(x,.59,z+(.09 if end=='Hind' else -.015))
  bone(end+'Upper.'+tag,(x,1.15,z),knee,'Body')
  bone(end+'Lower.'+tag,knee,(x,.085,z-.04),end+'Upper.'+tag)
bpy.ops.object.mode_set(mode='OBJECT')
def bind(o,group):
 if group is not None:
  g=o.vertex_groups.new(name=group);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 mod=o.modifiers.new('Native cow skin','ARMATURE');mod.object=rig;o.parent=rig
for name in bones:body.vertex_groups.new(name=name)
for v in body.data.vertices:
 p=body.matrix_world@v.co;gx,gy,gz=p.x,p.z,-p.y
 weights={'Body':1.0}
 if gz<-.95:
  h=min(1,max(0,(-gz-.95)/.24));weights={'Body':1-h,'Head':h}
 if gy<1.06 and abs(gx)>.18:
  end='Front' if gz<0 else 'Hind';tag='L' if gx<0 else 'R'
  leg=min(1,max(0,(1.1-gy)/.28));lower=min(1,max(0,(.67-gy)/.17))
  weights={'Body':1-leg,end+'Upper.'+tag:leg*(1-lower),end+'Lower.'+tag:leg*lower}
 for name,w in weights.items():
  if w>0:body.vertex_groups[name].add([v.index],w,'REPLACE')
bind(body,None)
for o,g in extras:bind(o,g)
rig.animation_data_create()
for clip,length in [('idle',3.0),('head_lower',4.0)]:
 action=bpy.data.actions.new(clip);rig.animation_data.action=action
 for frame in range(0,int(length*30)+1,3):
  phase=frame/(length*30)*math.tau
  for name in ['Head','Tail','Ear.L','Ear.R']:
   pb=rig.pose.bones[name];pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
   if name=='Head':pb.rotation_euler[0]=math.sin(phase)*.035+(.24 if clip=='head_lower' else 0)
   elif name=='Tail':pb.rotation_euler[1]=math.sin(phase)*.11
   else:pb.rotation_euler[1]=math.sin(phase+(.5 if name.endswith('L') else 1.1))*.10
   pb.keyframe_insert('rotation_euler',frame=frame)
 track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,0,action)
rig.animation_data.action=None;bpy.context.scene.frame_set(0)
WORK.mkdir(parents=True,exist_ok=True);OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'household_cow.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS')
manifest={'status':'original anatomical candidate; native/Godot visual review required','source':'tools/animals/build_household_cow.py; original geometry and rig, no external imagery','morphology_reference':'https://www.fao.org/4/t1265e/t1270e03.htm; not an authenticated 1857 breed','glb_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'vertices':sum(len(o.data.vertices) for o in [body]+[e[0] for e in extras]),'bones':len(bones),'clips':['idle','head_lower']}
(WORK/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('HOUSEHOLD COW BUILD',json.dumps(manifest))
