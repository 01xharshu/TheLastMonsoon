"""Reference-directed drape/flat leather construction; separate recoverable study."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_multiview_residual_candidate.blend'
OUT=ROOT/'WorkingAssets/Arjun/reference_fit'
REVIEW=ROOT/'docs/characters/arjun/reference_fit/projected_drape_2026-10-01'
REVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig=bpy.data.objects['Arjun_Rig']
cream=bpy.data.materials['Unbleached draped cotton']
leather=bpy.data.materials['Worn dark-brown leather']
edge=bpy.data.materials['Leather seams and welt']
brass=bpy.data.materials['Aged brass hardware']

def garment_weights(obj,kind,side):
 for v in obj.data.vertices:
  if kind=='boot':weights={'calf_'+side:1.0}
  elif kind=='foot':weights={'foot_'+side:1.0}
  else:
   t=max(0,min(1,(v.co.z-.43)/.16));weights={'thigh_'+side:t,'calf_'+side:1-t}
  for name,value in weights.items():
   group=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
   group.add([v.index],value,'REPLACE')
 obj.parent=rig
 arm=obj.modifiers.new('Reference garment skin','ARMATURE');arm.object=rig

def mesh_obj(name,verts,faces,mat,kind,side,thickness=0):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(mat)
 for p in mesh.polygons:p.use_smooth=True
 if thickness:
  solid=obj.modifiers.new('Real material thickness','SOLIDIFY');solid.thickness=thickness;solid.offset=0
 garment_weights(obj,kind,side)
 return obj

def leg_point(side,t,a,clearance=0):
 z=.205+t*.765;cx=side*(.196-.07*t);cy=-.005-.018*math.sin(t*math.pi)
 radius=.051+.052*math.sin(math.pi*t)**.90
 # Remove the old 13/21-rib corrugation. Unequal broad folds travel diagonally
 # across the front and gather into the boot rather than tracing straight tubes.
 envelope=math.sin(math.pi*t)**1.1
 # Narrow ridges separated by broad hanging cloth; gathers tighten at ankles.
 phase=5*a+side*t*16+1.7*math.sin(t*4)
 ridge=math.exp(-((math.sin(phase/2)/.22)**2))
 lower=math.exp(-((t-.19)/.17)**2)
 gather=math.exp(-((math.sin((t*73+2*a)/2)/.26)**2))
 fold=(.013*ridge-.002+.009*lower*gather)*envelope
 radius+=fold
 if z>.70:radius=min(radius,.236-abs(cx))
 if z<.30:radius=min(radius,.049)
 radius+=clearance
 return Vector((cx+radius*math.cos(a),cy+radius*1.02*math.sin(a),z))

for sign in [-1,1]:
 side='l' if sign>0 else 'r'
 obj=bpy.data.objects['Arjun_DrapedTrousers_'+str(sign)]
 obj.hide_render=True
 verts=[tuple(leg_point(sign,j/128,math.tau*i/192)) for j in range(129) for i in range(192)]
 faces=[]
 for j in range(128):
  for i in range(192):
   n=(i+1)%192;faces.append((j*192+i,j*192+n,(j+1)*192+n,(j+1)*192+i))
 obj=mesh_obj('Arjun_HangingDrape_'+side,verts,faces,cream,'cloth',side,.0012)
 obj['construction']='Dense narrow diagonal ridges and compressed ankle gathers'

# The old merged X tubes looked like round laces, unlike flat layered leather.
old=bpy.data.objects.get('Arjun_Detail_Leather seams and welt')
if old:old.hide_render=True

projection_errors=[]
boot_trees={}
deps=bpy.context.evaluated_depsgraph_get()
for sign in [-1,1]:
 shell=bpy.data.objects['Arjun_Boot_'+str(sign)].evaluated_get(deps)
 mesh=shell.to_mesh()
 boot_trees['l' if sign>0 else 'r']=BVHTree.FromPolygons([shell.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons])
 shell.to_mesh_clear()

def ribbon(name,points,width,mat,kind,side,normal_fn):
 verts=[];faces=[]
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
  normal=normal_fn(p).normalized();across=tangent.cross(normal).normalized()
  for sign in [-1,1]:
   q=p+across*sign*width/2
   if 'welt' not in name:
    hit,n,idx,d=boot_trees[side].find_nearest(q)
    if hit is not None:
     outward=Vector((hit.x-(.195 if side=='l' else -.195),hit.y+.006,0))
     if n.dot(outward)<0:n=-n
     q=hit+n*.0045
     projection_errors.append(abs((q-hit).length-.0045))
   else:q+=normal*.0013
   verts.append(tuple(q))
 for i in range(len(points)-1):faces.append((i*2,i*2+1,i*2+3,i*2+2))
 return mesh_obj(name,verts,faces,mat,kind,side,.0018)

for sign in [-1,1]:
 side='l' if sign>0 else 'r';cx=sign*.195
 for layer,height in enumerate([.145,.218,.277]):
  for crossing in [-1,1]:
   points=[]
   for i in range(97):
    a=math.tau*i/96;z=height+crossing*.019*math.sin(a)
    r=.053+.012*max(0,min(1,(z-.145)/.14))
    points.append(Vector((cx+r*math.cos(a),-.006+(r+.001)*math.sin(a),z)))
   ribbon('Flat boot wrap '+side+str(layer)+str(crossing),points,.014,leather,'boot',side,lambda p:Vector((p.x-cx,p.y+.006,0)))
 for row,y in enumerate([-.078,-.150]):
  points=[]
  for i in range(41):
   x=-.064+.128*i/40;z=.055+.027*math.sqrt(max(0,1-(x/.068)**2))
   points.append(Vector((cx+x,y,z)))
  ribbon('Flat vamp strap '+side+str(row),points,.016,leather,'foot',side,lambda p:Vector((0,0,1)))
 # Raised welt follows the foot outline, retaining heel/toe construction.
 points=[Vector((cx+.073*math.cos(a),-.073+.156*math.sin(a),.029)) for a in [math.tau*i/128 for i in range(129)]]
 ribbon('Leather outsole welt '+side,points,.004,edge,'foot',side,lambda p:Vector((p.x-cx,p.y+.073,0)))
 for height in [.146,.220,.278]:
  # Compact rectangular buckle frames on the outside shaft, aligned to leather.
  x=cx+sign*.069
  for pos,size in [((x,-.026,height-.010),(.003,.028,.0025)),((x,-.026,height+.010),(.003,.028,.0025)),((x,-.040,height),(.003,.0025,.022)),((x,-.012,height),(.003,.0025,.022))]:
   bpy.ops.mesh.primitive_cube_add(size=1,location=pos);part=bpy.context.object;part.name='Reference boot buckle '+side
   part.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
   # Bake location into vertices so skin rest coordinates remain rig-relative.
   for v in part.data.vertices:v.co+=part.location
   part.location=(0,0,0);part.data.materials.append(brass);garment_weights(part,'boot',side)

# Tension folds on the shirt/sash remain secondary to the reference silhouette.
scene=bpy.context.scene;camera=scene.camera
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=700;scene.render.resolution_y=950;scene.render.resolution_percentage=100
camera.data.type='ORTHO';camera.data.ortho_scale=1.92
camera.location=(0,-4,.88);camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
candidate=OUT/'arjun_projected_drape_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 camera.location=pos;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(REVIEW/(name+'.png'));bpy.ops.render.render(write_still=True)
report={'status':'CANDIDATE_VISUAL_REVIEW_OPEN','source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'candidate':str(candidate.relative_to(ROOT)),'candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'changes':['removed fine cylindrical trouser corrugation','dense hanging ridges and ankle gathers','shaft and vamp strips projected onto evaluated boot mesh'],'body_changed':False,'face_changed':False,'runtime_replaced':False,'exact_match':False,'projected_strap_vertices':len(projection_errors),'max_projection_offset_error_m':max(projection_errors,default=0)}
(REVIEW/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARJUN_DRAPE_BOOTS_RENDERED',flush=True)
