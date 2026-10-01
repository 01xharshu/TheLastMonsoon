"""Correct visible eye mapping and moustache strand thickness in separate source."""
import bpy,math,random,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_material_realism_candidate.blend'
OUT=ROOT/'docs/characters/arjun/reference_fit/eyes_moustache_2026-10-01';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
mat=bpy.data.materials.new('Arjun procedural brown iris and sclera');mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes['Principled BSDF'];tc=nt.nodes.new('ShaderNodeTexCoord');split=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(tc.outputs['Object'],split.inputs[0])
def mathnode(op,value=None):
 n=nt.nodes.new('ShaderNodeMath');n.operation=op
 if value is not None:n.inputs[1].default_value=value
 return n
absolute=mathnode('ABSOLUTE');nt.links.new(split.outputs['X'],absolute.inputs[0]);x=mathnode('SUBTRACT',.0300);nt.links.new(absolute.outputs[0],x.inputs[0]);z=mathnode('SUBTRACT',1.6073);nt.links.new(split.outputs['Z'],z.inputs[0]);combine=nt.nodes.new('ShaderNodeCombineXYZ');nt.links.new(x.outputs[0],combine.inputs['X']);nt.links.new(z.outputs[0],combine.inputs['Y']);length=nt.nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';nt.links.new(combine.outputs[0],length.inputs[0]);scale=mathnode('DIVIDE',.0065);nt.links.new(length.outputs['Value'],scale.inputs[0])
ramp=nt.nodes.new('ShaderNodeValToRGB');r=ramp.color_ramp;r.elements.remove(r.elements[1]);r.elements[0].position=0;r.elements[0].color=(.001,.0007,.0005,1)
for pos,color in [(.37,(.001,.0007,.0005,1)),(.41,(.045,.021,.007,1)),(.80,(.065,.031,.011,1)),(.94,(.008,.005,.003,1)),(1.0,(.55,.53,.49,1))]:
 e=r.elements.new(pos);e.color=color
nt.links.new(scale.outputs[0],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.20;bs.inputs['Specular IOR Level'].default_value=.4
obj=bpy.data.objects['Arjun_Eyes'];obj.data.materials.clear();obj.data.materials.append(mat)
# Use old moustache envelope, but replace the fused thick strands.
old=bpy.data.objects['Arjun_Detail_Soft black hair'];pts=[v.co.copy() for v in old.data.vertices];old.hide_render=True
xmin=min(p.x for p in pts);xmax=max(p.x for p in pts);zmin=min(p.z for p in pts);zmax=max(p.z for p in pts)
body=bpy.data.objects['Arjun_MakeHuman_Body'];ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());m=ev.to_mesh();tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in m.vertices],[tuple(p.vertices) for p in m.polygons]);ev.to_mesh_clear()
hair=bpy.data.materials['Soft black hair'];hbs=hair.node_tree.nodes['Principled BSDF'];hbs.inputs['Roughness'].default_value=.7
curve=bpy.data.curves.new('Fine individual moustache hairs','CURVE');curve.dimensions='3D';curve.bevel_depth=.00010;curve.bevel_resolution=1
random.seed(97);count=0
for i in range(1400):
 side=random.choice([-1,1]);u=random.random();x=side*(.0015+u*max(abs(xmin),abs(xmax))*.9)
 root_z=zmax-.001-(zmax-zmin)*(.12*u+random.uniform(0,.60))
 root,n,idx,d=tree.ray_cast(Vector((x,-.5,root_z)),Vector((0,1,0)))
 if root is None:continue
 spline=curve.splines.new('POLY');spline.points.add(6);count+=1
 length=random.uniform(.003,.0065)*(1-.35*u)
 for j,p in enumerate(spline.points):
  t=j/6;xx=x+side*.0018*t;zz=root_z-length*t
  hit,normal,idx,d=tree.ray_cast(Vector((xx,-.5,zz)),Vector((0,1,0)))
  if hit is None:hit=root;normal=n
  q=hit+normal*(.00025+.0003*math.sin(math.pi*t));p.co=(*q,1);p.radius=max(.08,1-t*.9)
obj=bpy.data.objects.new('Arjun_FineMoustacheStrands',curve);bpy.context.scene.collection.objects.link(obj);curve.materials.append(hair)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH');obj=bpy.context.object;group=obj.vertex_groups.new(name='head');group.add(list(range(len(obj.data.vertices))),1,'REPLACE');obj.parent=bpy.data.objects['Arjun_Rig'];mod=obj.modifiers.new('Head skin','ARMATURE');mod.object=obj.parent
# Remove the floating wire stripes and put a subdued weave pattern in the sash.
threads=bpy.data.objects.get('Arjun_Detail_Muted ochre sash thread')
if threads:threads.hide_render=True
sash=bpy.data.materials['Faded madder-red sash'];sn=sash.node_tree;sb=sn.nodes['Principled BSDF'];tc=sn.nodes.new('ShaderNodeTexCoord');wave=sn.nodes.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='Z';wave.inputs['Scale'].default_value=95;wave.inputs['Distortion'].default_value=2;sn.links.new(tc.outputs['Object'],wave.inputs['Vector']);ramp=sn.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.075,.010,.007,1);ramp.color_ramp.elements[1].color=(.125,.021,.012,1);sn.links.new(wave.outputs['Fac'],ramp.inputs[0]);sn.links.new(ramp.outputs[0],sb.inputs['Base Color'])
scene=bpy.context.scene;c=scene.camera;scene.cycles.samples=16;scene.render.resolution_x=900;scene.render.resolution_y=900;c.data.ortho_scale=.40;c.location=(0,-2,1.60);c.rotation_euler=(Vector((0,0,1.60))-c.location).to_track_quat('-Z','Y').to_euler()
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_eye_moustache_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate));scene.render.filepath=str(OUT/'face.png');bpy.ops.render.render(write_still=True)
c.location=(1,-2,1.60);c.rotation_euler=(Vector((0,0,1.60))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'face_three_quarter.png');bpy.ops.render.render(write_still=True)
c.data.ortho_scale=.55;c.location=(0,-2,1.16);c.rotation_euler=(Vector((0,0,1.16))-c.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'cloth.png');bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','candidate':str(candidate.relative_to(ROOT)),'strands':count,'old_moustache_bounds':[xmin,xmax,zmin,zmax],'exact_match':False,'runtime_replaced':False},indent=2)+'\n')
