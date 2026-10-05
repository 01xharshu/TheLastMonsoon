"""Separate surface repair on the measured candidate; preserves original evidence."""
import bpy,math,random,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/Arjun/reference_fit'
REVIEW=ROOT/'docs/characters/arjun/reference_fit'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'arjun_multiview_fit_candidate.blend'))
import sys
sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
ensure_full_body()
rig=bpy.data.objects['Arjun_Rig']
# Inspect eye geometry for a projective mapping anchored on actual globe centres.
eyes=bpy.data.objects['Arjun_Eyes']
points=[v.co for v in eyes.data.vertices]
centre_x=sum(abs(p.x) for p in points)/len(points)
centre_z=(min(p.z for p in points)+max(p.z for p in points))/2
mat=bpy.data.materials['Brown eyes'];nt=mat.node_tree
bs=nt.nodes.get('Principled BSDF');image=next(n for n in nt.nodes if n.type=='TEX_IMAGE')
tex=nt.nodes.new('ShaderNodeTexCoord');split=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(tex.outputs['Object'],split.inputs[0])
absolute=nt.nodes.new('ShaderNodeMath');absolute.operation='ABSOLUTE';nt.links.new(split.outputs['X'],absolute.inputs[0])
combine=nt.nodes.new('ShaderNodeCombineXYZ')
for channel,src,centre,offset in [('X',absolute.outputs[0],centre_x,.708),('Y',split.outputs['Z'],centre_z,.705)]:
 sub=nt.nodes.new('ShaderNodeMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=centre;nt.links.new(src,sub.inputs[0])
 scale=nt.nodes.new('ShaderNodeMath');scale.operation='MULTIPLY_ADD';scale.inputs[1].default_value=12.0;scale.inputs[2].default_value=offset
 nt.links.new(sub.outputs[0],scale.inputs[0]);nt.links.new(scale.outputs[0],combine.inputs[channel])
nt.links.new(combine.outputs[0],image.inputs['Vector']);image.extension='EXTEND'
bs.inputs['Roughness'].default_value=.23;bs.inputs['Specular IOR Level'].default_value=.38
# A separate fitted scalp volume and coherent locks replace the cap silhouette.
hair=bpy.data.objects['Arjun_WavyHair_Mpfb'];hair.hide_render=True
strand=bpy.data.materials.new('Arjun black wavy locks');strand.diffuse_color=(.007,.006,.005,1);strand.use_nodes=True
bs_hair=strand.node_tree.nodes['Principled BSDF'];bs_hair.inputs['Base Color'].default_value=strand.diffuse_color
bs_hair.inputs['Roughness'].default_value=.90;bs_hair.inputs['Specular IOR Level'].default_value=.18
# Continuous raised waves form the volume; tiny locks follow the same surface.
def hair_position(az,elev):
 wave=(.0035*math.sin(az*7+elev*4)+.0006*math.sin(az*31-elev*9))*math.cos(elev)**.6
 radii=Vector((.099+wave,.117+wave,.120+wave))
 return Vector((radii.x*math.cos(az)*math.cos(elev),.032*-1+radii.y*math.sin(az)*math.cos(elev),1.625+radii.z*math.sin(elev)+.012*math.exp(-((az%(math.tau)-4.7)/.65)**2)*math.sin(2*elev)**2))
def lower_edge(az): return -.18-.46*math.sin(az)
verts=[];faces=[]
for row in range(49):
 for col in range(129):
  az=math.tau*col/128;low=lower_edge(az)
  elev=low+(math.pi/2-low)*row/48
  verts.append(tuple(hair_position(az,elev)))
for row in range(48):
 for col in range(128):
  a=row*129+col;faces.append((a,a+1,a+130,a+129))
mesh=bpy.data.meshes.new('Reference wavy crown surface');mesh.from_pydata(verts,[],faces);mesh.update()
cap=bpy.data.objects.new('Arjun_Reference_WavyCrown',mesh);bpy.context.scene.collection.objects.link(cap);mesh.materials.append(strand)
for poly in mesh.polygons:poly.use_smooth=True
vg=cap.vertex_groups.new(name='head');vg.add(list(range(len(mesh.vertices))),1,'REPLACE')
arm=cap.modifiers.new('Reference hair skin','ARMATURE');arm.object=rig;cap.parent=rig
random.seed(22)
curve=bpy.data.curves.new('Arjun reference crown waves','CURVE');curve.dimensions='3D';curve.resolution_u=2;curve.bevel_depth=.00038;curve.bevel_resolution=1
for lock in range(1250):
 az=random.uniform(-math.pi,math.pi);low=lower_edge(az);elev=random.uniform(low+.02,1.51)
 spline=curve.splines.new('POLY');spline.points.add(11)
 phase=random.uniform(0,math.tau)
 for j,p in enumerate(spline.points):
  t=j/11
  a=az+(t-.5)*.28+.025*math.sin(t*math.pi*2+phase)
  e=max(lower_edge(a),min(1.56,elev+(t-.5)*.06+.018*math.sin(t*math.pi*2+phase)))
  position=hair_position(a,e)
  normal=(position-Vector((0,-.032,1.625))).normalized()
  position+=normal*(.0007+.0013*math.sin(math.pi*t))
  p.co=(*position,1);p.radius=.6+.4*math.sin(math.pi*t)
strand_count=len(curve.splines)
obj=bpy.data.objects.new('Arjun_Reference_WavyLocks',curve);bpy.context.scene.collection.objects.link(obj);curve.materials.append(strand)
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=obj;obj.select_set(True)
bpy.ops.object.convert(target='MESH');obj=bpy.context.object
vg=obj.vertex_groups.new(name='head');vg.add(list(range(len(obj.data.vertices))),1,'REPLACE')
arm=obj.modifiers.new('Reference hair skin','ARMATURE');arm.object=rig;obj.parent=rig
# Moderate iris size and saturation while preserving visible sclera.
scale_x=next(n for n in nt.nodes if n.type=='MATH' and n.operation=='MULTIPLY_ADD')
for n in nt.nodes:
 if n.type=='MATH' and n.operation=='MULTIPLY_ADD':n.inputs[1].default_value=15.0
hue=nt.nodes.new('ShaderNodeHueSaturation');hue.inputs['Saturation'].default_value=.55;hue.inputs['Value'].default_value=.9
nt.links.new(image.outputs['Color'],hue.inputs['Color']);nt.links.new(hue.outputs['Color'],bs.inputs['Base Color'])
# Keep hidden trouser sections beneath the kurta and inside boot shafts.
# A cut silhouette in the earlier render was penetration, not a hem fold.
for side in [-1,1]:
 obj=bpy.data.objects['Arjun_DrapedTrousers_'+str(side)]
 for v in obj.data.vertices:
  t=max(0,min(1,(v.co.z-.205)/.765));cx=side*(.196-.07*t);cy=-.005-.018*math.sin(t*math.pi)
  dx=v.co.x-cx;dy=v.co.y-cy;radius=math.sqrt(dx*dx+dy*dy)
  max_radius=10.0
  if v.co.z>.70:max_radius=.237-abs(cx)
  if v.co.z<.30:max_radius=.049
  if radius>max_radius:
   v.co.x=cx+dx*max_radius/radius;v.co.y=cy+dy*max_radius/radius
hem=bpy.data.objects['Arjun_Kurta_SplitHem']
for v in hem.data.vertices:
 for group in list(hem.vertex_groups):
  if group.name in ['thigh_l','thigh_r']:group.remove([v.index])
 group=hem.vertex_groups.get('pelvis') or hem.vertex_groups.new(name='pelvis');group.add([v.index],1,'REPLACE')
# Reference charcoal is neutral; source blue tint and even upper cloth looked new.
mat=bpy.data.materials['Weathered charcoal cotton']
for node in mat.node_tree.nodes:
 if node.type=='VALTORGB':
  for stop in node.color_ramp.elements:
   mean=sum(stop.color[:3])/3;stop.color=(mean,mean,mean,stop.color[3])
upper=bpy.data.objects['Arjun_Kurta_Upper']
for v in upper.data.vertices:
 waist=math.exp(-((v.co.z-1.11)/.08)**2)
 sleeve=math.exp(-((abs(v.co.x)-.32)/.09)**2)*math.exp(-((v.co.z-1.20)/.15)**2)
 offset=(.003*waist+.0035*sleeve)*math.sin(v.co.x*46+v.co.z*37)
 normal=Vector((v.co.x*.35,v.co.y,0)).normalized()
 v.co+=normal*offset
scene=bpy.context.scene;camera=scene.camera
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
camera.data.type='ORTHO';camera.data.ortho_scale=.38
camera.location=(0,-2,1.592);camera.rotation_euler=(Vector((0,0,1.567))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
source=OUT/'arjun_multiview_surface_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
scene.render.filepath=str(REVIEW/'face_surface.png');bpy.ops.render.render(write_still=True)
scene.render.resolution_x=700;scene.render.resolution_y=950;camera.data.ortho_scale=1.92
for name,pos in [('front_surface',(0,-4,.88)),('side_surface',(4,0,.88)),('back_surface',(0,4,.88)),('three_quarter_surface',(3,-4,.88))]:
 camera.location=pos;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(REVIEW/(name+'.png'));bpy.ops.render.render(write_still=True)
report={'status':'REFERENCE_SURFACE_CANDIDATE_REVIEW_OPEN','source':str(source.relative_to(ROOT)), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'eye_centres':[centre_x,centre_z],'hair_strands':strand_count,'runtime_replaced':False}
(REVIEW/'surface_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARJUN_REFERENCE_SURFACE_RENDERED',flush=True)
