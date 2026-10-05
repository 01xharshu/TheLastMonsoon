"""Separate reference hair-volume study; rendered likeness remains the gate."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_projected_drape_candidate.blend'
OUT=ROOT/'docs/characters/arjun/reference_fit/hair_clumps_2026-10-01'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
import sys
sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
ensure_full_body()
rig=bpy.data.objects['Arjun_Rig']
mat=bpy.data.materials['Arjun black wavy locks']
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.78;bs.inputs['Specular IOR Level'].default_value=.16
random.seed(72)
curve=bpy.data.curves.new('Tousled wave clumps','CURVE');curve.dimensions='3D';curve.bevel_depth=.0013;curve.bevel_resolution=2
for i in range(180):
 a=random.uniform(0,math.tau);low=-.18-.46*math.sin(a)
 e=random.uniform(low+.12,1.44);length=random.uniform(.27,.55);phase=random.uniform(0,math.tau)
 spline=curve.splines.new('POLY');spline.points.add(23)
 for j,p in enumerate(spline.points):
  t=j/23;az=a+(t-.5)*length+.04*math.sin(t*math.tau+phase)
  el=max(-.18-.46*math.sin(az)+.025,min(1.54,e+.055*math.sin(t*math.tau+phase)))
  bulge=.006+.007*math.sin(math.pi*t)**2
  pos=Vector(((.099+bulge)*math.cos(az)*math.cos(el),-.032+(.117+bulge)*math.sin(az)*math.cos(el),1.625+(.120+bulge)*math.sin(el)))
  p.co=(*pos,1);p.radius=.12+.88*math.sin(math.pi*t)**.7
obj=bpy.data.objects.new('Arjun_TousledWaveClumps',curve);bpy.context.scene.collection.objects.link(obj);curve.materials.append(mat)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH');obj=bpy.context.object
vg=obj.vertex_groups.new(name='head');vg.add(list(range(len(obj.data.vertices))),1,'REPLACE');obj.parent=rig;arm=obj.modifiers.new('Head skin','ARMATURE');arm.object=rig
scene=bpy.context.scene;camera=scene.camera;scene.cycles.samples=24
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_hair_clump_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 camera.location=pos;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','source':str(SOURCE.relative_to(ROOT)),'candidate':str(candidate.relative_to(ROOT)),'clumps':180,'exact_match':False,'runtime_replaced':False},indent=2)+'\n')
