"""Original female zebu-type candidate; no third-party geometry or textures."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/animals/cow/household_cow.glb'
WORK=ROOT/'WorkingAssets/Animals/household_cow'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def point(p):return Vector((p[0],-p[2],p[1]))
def mat(name,color,rough=.72):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=rough
 return m
coat=mat('Original warm grey coat',(.46,.445,.395));dark=mat('Dark muzzle and cloven hooves',(.10,.08,.065));horn=mat('Horn keratin',(.39,.34,.25));eye=mat('Dark wet eye',(.022,.016,.010),.20);pink=mat('Udder skin',(.30,.24,.20));inside=mat('Ear inner skin',(.48,.39,.30))
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
def loft(name,sections,material=coat,group='Body',skin=True):
 verts=[];faces=[];count=32
 for z,y,width,height in sections:
  for i in range(count):
   a=i/count*math.tau;verts.append(point((math.cos(a)*width,y+math.sin(a)*height,z)))
 for row in range(len(sections)-1):
  for col in range(count):
   a=row*count+col;b=row*count+(col+1)%count;faces.append((a,a+count,b+count,b))
 faces.extend([tuple(range(count-1,-1,-1)),tuple(range((len(sections)-1)*count,len(sections)*count))])
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.materials.append(material)
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
 for poly in data.polygons:poly.use_smooth=True
 bpy.context.view_layer.objects.active=o
 sub=o.modifiers.new('Anatomical surface interpolation','SUBSURF');sub.levels=2;sub.render_levels=2;bpy.ops.object.modifier_apply(modifier=sub.name)
 (parts if skin else extras).append((o,group));return o
def limb(name,a,b,profile,group):
 # Continuous rings along each limb avoid separate ball/cone joint silhouettes.
 pa,pb=point(a),point(b);axis=(pb-pa).normalized()
 u=Vector((1,0,0));v=axis.cross(u).normalized();verts=[];faces=[];count=20
 for t,radius in profile:
  centre=pa.lerp(pb,t)
  for i in range(count):
   angle=i/count*math.tau
   verts.append(centre+u*math.cos(angle)*radius*.93+v*math.sin(angle)*radius)
 for ring in range(len(profile)-1):
  for i in range(count):
   a0=ring*count+i;a1=ring*count+(i+1)%count
   faces.append((a0,a1,a1+count,a0+count))
 faces.extend([tuple(range(count-1,-1,-1)),tuple(range((len(profile)-1)*count,len(profile)*count))])
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.materials.append(coat)
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
 for face in data.polygons:face.use_smooth=True
 parts.append((obj,group));return obj
# Authored cross-sections keep a straighter back and distinguish brisket, ribcage and pelvis.
loft('Female ribcage and pelvis',[(-.84,1.14,.18,.23),(-.68,1.20,.255,.36),(-.51,1.19,.30,.375),(-.30,1.13,.33,.345),(-.04,1.09,.345,.345),(.23,1.10,.35,.345),(.49,1.15,.285,.295),(.68,1.18,.29,.285),(.85,1.18,.19,.225),(.94,1.16,.06,.13)])
# Withers are integrated into the ribcage sections rather than a separate lump.
loft('Tapered female neck',[(-.69,1.18,.23,.28),(-.90,1.20,.19,.29),(-1.10,1.25,.145,.225)])
loft('Bovine forehead cheek and nasal planes',[(-1.08,1.28,.135,.19),(-1.20,1.28,.160,.205),(-1.32,1.22,.158,.19),(-1.43,1.12,.137,.155),(-1.54,1.01,.127,.112),(-1.64,.94,.121,.073)],group='Head')
ellipsoid('Cheek mass',(0,1.155,-1.285),(.15,.12,.14),coat,'Head',True)
loft('Continuous lower mandible',[(-1.20,1.06,.125,.10),(-1.34,1.015,.125,.085),(-1.50,.94,.113,.069),(-1.62,.91,.102,.046)],coat,'Jaw',True)
muzzle=ellipsoid('Muzzle',(0,.93,-1.64),(.145,.076,.095),dark,'Head',False)
# Female dewlap is a thin folded sheet rather than a bulb beneath the throat.
loft('Folded dewlap',[(-.57,.89,.035,.13),(-.78,.87,.035,.19),(-.97,.94,.032,.20),(-1.13,1.03,.025,.13)])
for side in [-1,1]:
 tag='L' if side<0 else 'R';x=side*.27
 for end,z in [('Front',-.60),('Hind',.62)]:
  upper=(x,1.15,z);knee=(x,.59,z+(.09 if end=='Hind' else -.015));fetlock=(x,.085,z-.04)
  if end=='Hind':ellipsoid('Hindquarter muscle '+tag,(x,.995,.69),(.115,.235,.16),group=end+'Upper.'+tag)
  else:ellipsoid('Scapular muscle '+tag,(side*.245,1.10,-.50),(.060,.19,.15),group=end+'Upper.'+tag)
  limb(end+' upper anatomy '+tag,upper,knee,[(0,.094),(.18,.088),(.45,.075),(.72,.056),(.90,.049),(1,.051)],end+'Upper.'+tag)
  ellipsoid(end+' joint '+tag,knee,(.052,.062,.055),group=end+'Lower.'+tag)
  limb(end+' tapered tendon '+tag,knee,fetlock,[(0,.046),(.12,.043),(.38,.035),(.68,.028),(.85,.031),(1,.034)],end+'Lower.'+tag)
  ellipsoid('Fetlock '+end+tag,(x,.13,z-.04),(.044,.067,.047),group=end+'Lower.'+tag)
  for split in [-1,1]:
   # Authored keratin walls: flat sole, wider toe, taper into the coronet.
   verts=[];faces=[];count=12
   rings=[(.002,.024,.060),(.013,.027,.078),(.061,.026,.067),(.101,.019,.041)]
   for height,width,length in rings:
    for i in range(count):
     angle=i/count*math.tau
     # Rounded squarish section, rather than a spherical shoe.
     sx=math.copysign(abs(math.cos(angle))**.65,math.cos(angle))
     sz=math.copysign(abs(math.sin(angle))**.65,math.sin(angle))
     verts.append(point((x+split*.030+sx*width,height,z-.085+sz*length)))
   for row in range(len(rings)-1):
    for i in range(count):
     a=row*count+i;b=row*count+(i+1)%count
     faces.append((a,a+count,b+count,b))
   faces.extend([tuple(range(count)),tuple(range(len(rings)*count-1,(len(rings)-1)*count-1,-1))])
   data=bpy.data.meshes.new('Cloven hoof wall');data.from_pydata(verts,[],faces);data.materials.append(dark)
   hoof=bpy.data.objects.new('Cloven hoof '+end+tag+str(split),data);bpy.context.collection.objects.link(hoof)
   for face in data.polygons:face.use_smooth=len(face.vertices)==4
   extras.append((hoof,end+'Foot.'+tag))
 # A continuous swept horn removes the old angular cone join.
 curve=[]
 for step in range(15):
  t=step/14
  curve.append((side*(.095+.083*t-.025*t*t),1.425+.24*t,-1.16+.065*math.sin(t*math.pi)-.055*t*t))
 verts=[];faces=[];sides=16
 for row,c in enumerate(curve):
  tangent=point(curve[min(row+1,14)])-point(curve[max(row-1,0)])
  tangent.normalize();u=tangent.cross(Vector((0,1,0))).normalized();v=tangent.cross(u).normalized()
  radius=.033*(1-row/14)**.8+.001
  for column in range(sides):
   angle=column/sides*math.tau;verts.append(point(c)+(u*math.cos(angle)+v*math.sin(angle))*radius)
 for row in range(14):
  for column in range(sides):
   a=row*sides+column;b=row*sides+(column+1)%sides;faces.append((a,b,b+sides,a+sides))
 faces.extend([tuple(range(sides-1,-1,-1)),tuple(range(14*sides,15*sides))])
 data=bpy.data.meshes.new('Swept horn '+tag);data.from_pydata(verts,[],faces);data.materials.append(horn)
 o=bpy.data.objects.new('Curved horn '+tag,data);bpy.context.collection.objects.link(o)
 for face in data.polygons:face.use_smooth=True
 extras.append((o,'Head'))
 # Long leaf-like ears with a recessed inner surface.
 ear=ellipsoid('Ear '+tag,(side*.225,1.35,-1.14),(.165,.018,.074),coat,'Ear.'+tag,False)
 for vertex in ear.data.vertices:
  tip=max(0,side*vertex.co.x/.14);vertex.co.z-=.020*tip*tip;vertex.co.y-=.015*tip*tip
 ear.rotation_euler[1]=side*.18
 # Fitted upper ear surface follows the thin outer shell at 1 mm clearance.
 verts=[point((0,.019,0))];faces=[];count=32
 for row in range(1,6):
  r=row/5
  for i in range(count):
   angle=i/count*math.tau;x=.130*r*math.cos(angle);z=.049*r*math.sin(angle)
   height=.018*math.sqrt(max(0,1-(x/.165)**2-(z/.074)**2))+.001
   tip=max(0,side*x/.14)
   verts.append(point((x,height-.020*tip*tip,z+.015*tip*tip)))
 for i in range(count):faces.append((0,1+(i+1)%count,1+i))
 for row in range(4):
  for i in range(count):
   a=1+row*count+i;b=1+row*count+(i+1)%count
   faces.append((a,b,b+count,a+count))
 data=bpy.data.meshes.new('Fitted inner ear');data.from_pydata(verts,[],faces);data.materials.append(inside)
 inner=bpy.data.objects.new('Ear inner '+tag,data);bpy.context.collection.objects.link(inner)
 inner.location=point((side*.225,1.35,-1.145));inner.rotation_euler[1]=side*.18
 for face in data.polygons:face.use_smooth=True
 extras.append((inner,'Ear.'+tag))
 # An open lid cuff seats the eye within the cheek instead of a bead on it.
 verts=[];faces=[];count=32
 for radius,lateral in [(1.0,.150),(.84,.166),(.68,.168)]:
  for i in range(count):
   angle=i/count*math.tau
   verts.append(point((side*lateral,1.285+math.sin(angle)*.026*radius,-1.30+math.cos(angle)*.040*radius)))
 for row in range(2):
  for i in range(count):
   a=row*count+i;b=row*count+(i+1)%count
   faces.append((a,a+count,b+count,b) if side>0 else (a,b,b+count,a+count))
 data=bpy.data.meshes.new('Anatomical eyelid cuff');data.from_pydata(verts,[],faces);data.materials.append(coat)
 lid=bpy.data.objects.new('Eyelid '+tag,data);bpy.context.collection.objects.link(lid)
 for face in data.polygons:face.use_smooth=True
 extras.append((lid,'Head'))
 ellipsoid('Eye '+tag,(side*.164,1.285,-1.30),(.006,.016,.026),eye,'Head',False)
 iris=mat('Natural brown iris '+tag,(.105,.047,.016),.32)
 ellipsoid('Iris '+tag,(side*.170,1.285,-1.30),(.001,.010,.020),iris,'Head',False)
 ellipsoid('Pupil '+tag,(side*.1715,1.285,-1.30),(.001,.004,.011),eye,'Head',False)
 cutter=ellipsoid('Nostril opening cutter '+tag,(side*.076,.955,-1.713),(.024,.014,.024),eye,'Head',False)
 extras.pop();bpy.context.view_layer.objects.active=muzzle
 cut=muzzle.modifiers.new('Inset nostril '+tag,'BOOLEAN');cut.operation='DIFFERENCE';cut.object=cutter
 bpy.ops.object.modifier_apply(modifier=cut.name);bpy.data.objects.remove(cutter,do_unlink=True)
 ellipsoid('Nostril '+tag,(side*.076,.955,-1.697),(.020,.010,.006),eye,'Head',False)
segment('Mouth crease',(-.09,.903,-1.691),(.09,.903,-1.691),.004,.004,eye,'Jaw',False)
ellipsoid('Udder',(0,.79,.57),(.14,.11,.18),pink,'Body',False)
for x in [-.07,.07]:
 for z in [.49,.64]:segment('Teat',(x,.68,z),(x,.60,z),.021,.013,pink,'Body',False)
segment('Tail skin',(0,1.28,.90),(0,.41,1.02),.030,.013,coat,'Tail',False)
ellipsoid('Tail switch',(0,.27,1.04),(.035,.16,.038),dark,'Tail',False)
# Weld the original body forms into one continuous skin. Preserve appendages.
bpy.ops.object.select_all(action='DESELECT')
for o,_ in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0][0];bpy.ops.object.join();body=bpy.context.object;body.name='Continuous cow skin'
remesh=body.modifiers.new('Welded original anatomy','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.011;remesh.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=body.modifiers.new('Surface relaxation','SMOOTH');smooth.factor=.7;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
dec=body.modifiers.new('Game skin budget','DECIMATE');dec.ratio=.48;bpy.ops.object.modifier_apply(modifier=dec.name)
for face in body.data.polygons:face.use_smooth=True
# Original vertex coat variation exports without relying on unsupported procedural materials.
colors=body.data.color_attributes.new(name='CoatVariation',type='FLOAT_COLOR',domain='POINT')
for v in body.data.vertices:
 p=body.matrix_world@v.co
 neck=max(0,min(1,(-(-p.y)-.55)/.65))
 shade=1-.13*neck-.035*math.sin(p.z*23+p.y*7)*math.sin(p.x*31)
 colors.data[v.index].color=(.46*shade,.445*shade,.395*shade,1)
coat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(1,1,1,1)
vertex_node=coat.node_tree.nodes.new('ShaderNodeVertexColor');vertex_node.layer_name='CoatVariation'
coat.node_tree.links.new(vertex_node.outputs['Color'],coat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
# Native rig and explicit source-authored weights.
bpy.ops.object.armature_add(location=(0,0,0));rig=bpy.context.object;rig.name='HouseholdCowRig';bpy.ops.object.mode_set(mode='EDIT');eb=rig.data.edit_bones;eb.remove(eb[0]);bones={}
def bone(name,a,b,parent=None):
 v=eb.new(name);v.head=point(a);v.tail=point(b)
 if parent:v.parent=bones[parent]
 bones[name]=v
bone('Body',(0,1.10,.65),(0,1.10,-.6))
bone('Neck',(0,1.21,-.63),(0,1.27,-1.10),'Body')
bone('Head',(0,1.27,-1.10),(0,.93,-1.74),'Neck')
bone('Jaw',(0,1.11,-1.25),(0,1.04,-1.56),'Head')
bone('Tail',(0,1.28,.90),(0,.4,1.02),'Body')
for side in [-1,1]:
 tag='L' if side<0 else 'R';x=side*.27
 bone('Ear.'+tag,(side*.16,1.23,-1.25),(side*.37,1.23,-1.25),'Head')
 for end,z in [('Front',-.60),('Hind',.62)]:
  knee=(x,.59,z+(.09 if end=='Hind' else -.015))
  bone(end+'Upper.'+tag,(x,1.15,z),knee,'Body')
  bone(end+'Lower.'+tag,knee,(x,.085,z-.04),end+'Upper.'+tag)
  bone(end+'Foot.'+tag,(x,.085,z-.04),(x,.009,z-.12),end+'Lower.'+tag)
bpy.ops.object.mode_set(mode='OBJECT')
def bind(o,group):
 if group is not None:
  g=o.vertex_groups.new(name=group);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 mod=o.modifiers.new('Native cow skin','ARMATURE');mod.object=rig;o.parent=rig
for name in bones:body.vertex_groups.new(name=name)
for v in body.data.vertices:
 p=body.matrix_world@v.co;gx,gy,gz=p.x,p.z,-p.y
 weights={'Body':1.0}
 if gz<-.64:
  n=min(1,max(0,(-gz-.64)/.30));h=min(1,max(0,(-gz-1.02)/.26));weights={'Body':1-n,'Neck':n*(1-h),'Head':n*h}
 if gy<.98 and -1.68<gz<-1.22:
  jaw=min(1,max(0,(.98-gy)/.06));weights={'Head':1-jaw,'Jaw':jaw}
 if gy<1.12 and abs(gx)>.14:
  end='Front' if gz<0 else 'Hind';tag='L' if gx<0 else 'R'
  centre_z=-.60 if end=='Front' else .62
  distance=math.hypot(abs(gx)-.27,gz-centre_z)
  # Belly/flank skin between limbs remains with the torso during every stride.
  radial=max(0,min(1,(.20-distance)/.085));radial=radial*radial*(3-2*radial)
  leg=min(1,max(0,(1.13-gy)/.30))*radial;lower=min(1,max(0,(.67-gy)/.17))
  weights={'Body':1-leg,end+'Upper.'+tag:leg*(1-lower),end+'Lower.'+tag:leg*lower}
 for name,w in weights.items():
  if w>0:body.vertex_groups[name].add([v.index],w,'REPLACE')
bind(body,None)
body.shape_key_add(name='Basis')
breath=body.shape_key_add(name='Breath')
for v in body.data.vertices:
 p=body.matrix_world@v.co;gx,gy,gz=p.x,p.z,-p.y
 flank=math.exp(-((gz-.10)/.53)**2)*max(0,min(1,(gy-.78)/.30))*max(0,min(1,(abs(gx)-.15)/.15))
 breath.data[v.index].co.x+=math.copysign(.006*flank,gx)
 breath.data[v.index].co.z+=.001*flank
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
# Editable UV islands also provide valid tangent data for exported morph normals.
for obj in [body]+[entry[0] for entry in extras]:
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 if obj.data.shape_keys:obj.active_shape_key_index=0
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
 bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015)
 bpy.ops.object.mode_set(mode='OBJECT')
WORK.mkdir(parents=True,exist_ok=True);OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'household_cow.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS')
manifest={'status':'broader bovine facial planes and cheeks, shaped cloven walls/flat soles, fitted eyelids/thin inner ears, subtle Breath morph, layered procedural pigmentation; 19-bone rig and target contract retained; final art approval open','source':'tools/animals/build_household_cow.py; original geometry and rig, no external imagery','morphology_reference':'https://www.fao.org/4/t1265e/t1270e03.htm; not an authenticated 1857 breed','glb_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'vertices':sum(len(o.data.vertices) for o in [body]+[e[0] for e in extras]),'bones':len(bones),'morphs':['Breath'],'clips':['idle','head_lower']}
(WORK/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('HOUSEHOLD COW BUILD',json.dumps(manifest))
