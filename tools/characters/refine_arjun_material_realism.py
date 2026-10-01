"""Recoverable cloth/skin/leather realism study; does not establish likeness."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_sculpted_hair_candidate.blend'
OUT=ROOT/'docs/characters/arjun/reference_fit/material_realism_2026-10-01';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
def noise(nt,coord,scale,detail=2):
 n=nt.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail;nt.links.new(coord,n.inputs['Vector']);return n
for name,color in [('Weathered charcoal cotton',(.008,.008,.008)),('Unbleached draped cotton',(.62,.56,.45)),('Faded madder-red sash',(.12,.017,.013))]:
 mat=bpy.data.materials[name];nt=mat.node_tree;bs=nt.nodes['Principled BSDF'];tc=nt.nodes.new('ShaderNodeTexCoord');coord=tc.outputs['Object']
 wear=noise(nt,coord,135,3);ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=tuple(c*.82 for c in color)+(1,);ramp.color_ramp.elements[1].color=tuple(c*1.15 for c in color)+(1,);nt.links.new(wear.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
 waves=[]
 for direction in ['X','Z']:
  w=nt.nodes.new('ShaderNodeTexWave');w.wave_type='BANDS';w.bands_direction=direction;w.inputs['Scale'].default_value=1600;w.inputs['Distortion'].default_value=.8;nt.links.new(coord,w.inputs['Vector']);waves.append(w)
 mult=nt.nodes.new('ShaderNodeMath');mult.operation='MULTIPLY';nt.links.new(waves[0].outputs['Fac'],mult.inputs[0]);nt.links.new(waves[1].outputs['Fac'],mult.inputs[1])
 fine=nt.nodes.new('ShaderNodeBump');fine.inputs['Strength'].default_value=.16;fine.inputs['Distance'].default_value=.00012;nt.links.new(mult.outputs[0],fine.inputs['Height'])
 # Stretched noise adds shallow directional crumpling, without changing silhouette.
 mapping=nt.nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(1.5,2,6);nt.links.new(coord,mapping.inputs[0]);fold=noise(nt,mapping.outputs[0],38,2)
 broad=nt.nodes.new('ShaderNodeBump');broad.inputs['Strength'].default_value=.20;broad.inputs['Distance'].default_value=.0008;nt.links.new(fold.outputs['Fac'],broad.inputs['Height']);nt.links.new(fine.outputs['Normal'],broad.inputs['Normal']);nt.links.new(broad.outputs['Normal'],bs.inputs['Normal'])
 bs.inputs['Roughness'].default_value=.9;bs.inputs['Sheen Weight'].default_value=.025;bs.inputs['Sheen Roughness'].default_value=.8
skin=bpy.data.materials['Arjun warm medium-brown skin'];nt=skin.node_tree;bs=nt.nodes['Principled BSDF'];tc=nt.nodes.new('ShaderNodeTexCoord');pores=noise(nt,tc.outputs['Object'],2400,2);bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00007;bump.inputs['Strength'].default_value=.2;nt.links.new(pores.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs['Normal'],bs.inputs['Normal']);bs.inputs['Roughness'].default_value=.52;bs.inputs['Subsurface Weight'].default_value=.035
for name in ['Worn dark-brown leather','Leather seams and welt']:
 nt=bpy.data.materials[name].node_tree;bs=nt.nodes['Principled BSDF'];tc=nt.nodes.new('ShaderNodeTexCoord');grain=noise(nt,tc.outputs['Object'],1250,2);b=nt.nodes.new('ShaderNodeBump');b.inputs['Distance'].default_value=.00016;b.inputs['Strength'].default_value=.24;nt.links.new(grain.outputs['Fac'],b.inputs['Height']);nt.links.new(b.outputs['Normal'],bs.inputs['Normal']);bs.inputs['Roughness'].default_value=.67
# Recess the continuous crown beneath locks so their roots cast small gaps/shadows.
cap=bpy.data.objects['Arjun_SculptedCrown']
for v in cap.data.vertices:
 n=(v.co-Vector((0,-.02,1.626))).normalized();v.co-=n*.002
scene=bpy.context.scene;camera=scene.camera;scene.cycles.samples=20
camera.location=(0,-4,.88);camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
candidate=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_material_realism_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
for name,pos in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 camera.location=pos;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'status':'VISUAL_REVIEW_OPEN','candidate':str(candidate.relative_to(ROOT)),'exact_match':False,'runtime_replaced':False,'changes':['cotton warp/weft microbump','subtle directional cloth crumpling','reduced mottled cloth contrast','skin pore bump','fine leather grain','hair roots recessed 2mm']},indent=2)+'\n')
