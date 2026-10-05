"""Reversible owner-board fit; new Blender source and review renders only."""
import bpy, math, json, hashlib, sys
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from fit_arjun_reference_face import calibrate, apply_reference_fit, shaped_coordinates, gaussian
SOURCE=ROOT/'WorkingAssets/Arjun/candidate/arjun_reference_candidate.blend'
OUT=ROOT/'WorkingAssets/Arjun/reference_fit'
REVIEW=ROOT/'docs/characters/arjun/reference_fit'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
import sys
sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
ensure_full_body()
body=bpy.data.objects['Arjun_MakeHuman_Body']
calibrate()
report=apply_reference_fit(body)
data=json.loads((OUT/'reference_face_fit.json').read_text())
centers=np.array([c['source_local'] for c in data['controls']])
deltas=np.array([c['delta_local'] for c in data['controls']])
weights=np.linalg.solve(gaussian(centers,centers,data['kernel_width_m'])+np.eye(len(centers))*data['regularization'],deltas)
for name in ['Arjun_Eyebrows','Arjun_Detail_Soft black hair']:
 obj=bpy.data.objects.get(name)
 if not obj: continue
 points=np.array([v.co[:] for v in obj.data.vertices])
 move=gaussian(points,centers,data['kernel_width_m'])@weights*data['strength']
 lengths=np.linalg.norm(move,axis=1)
 move*=np.minimum(1,.020/np.maximum(lengths,1e-9))[:,None]
 for vertex,offset in zip(obj.data.vertices,move): vertex.co+=Vector(offset)
# Preserve fitted eyes: frontal fitting keeps pupil centres as scale anchors.
hair=bpy.data.objects['Arjun_WavyHair_Mpfb']
for v in hair.data.vertices:
 crown=max(0,min(1,(v.co.z-1.60)/.10))
 v.co.x*=1+.09*crown
 v.co.z+=.016*crown
 v.co.y-=.006*crown
for side in [-1,1]:
 obj=bpy.data.objects['Arjun_DrapedTrousers_'+str(side)]
 for v in obj.data.vertices:
  t=max(0,min(1,(v.co.z-.205)/.765))
  cx=side*(.196-.07*t);cy=-.005-.018*math.sin(t*math.pi)
  dx=v.co.x-cx;dy=v.co.y-cy
  angle=math.atan2(dy,dx)
  old=.052+.048*math.sin(math.pi*t)**1.2
  new=.052+.071*math.sin(math.pi*t)**1.05
  envelope=math.sin(math.pi*t)**1.2
  fold=.008*math.sin(angle*3-t*10+side*.8)*envelope
  diagonal=.003*math.sin(angle*7+t*19)*envelope
  factor=(new+fold+diagonal)/old
  v.co.x=cx+dx*factor;v.co.y=cy+dy*factor
 obj['construction']='Reference-fit full draped legs; broad diagonal gathers, boot opening retained'
hem=bpy.data.objects['Arjun_Kurta_SplitHem']
for v in hem.data.vertices:
 loose=max(0,min(1,(1.04-v.co.z)/.33))
 angle=math.atan2(v.co.y+.022,v.co.x)
 v.co.z-=.015*math.cos(angle*2)*loose**2
# Age the cotton mildly without importing a new colour direction.
for name in ['Weathered charcoal cotton','Unbleached draped cotton']:
 mat=bpy.data.materials.get(name)
 if mat:
  for node in mat.node_tree.nodes:
   if node.type=='TEX_NOISE' and node.inputs['Scale'].default_value < 100:
    node.inputs['Scale'].default_value=28
# Core outfit has no added belt/harness. Equipped mounts are a separate runtime layer.
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=700;scene.render.resolution_y=950;scene.render.resolution_percentage=100
camera=scene.camera;camera.data.type='ORTHO';camera.data.ortho_scale=1.92
OUT.mkdir(exist_ok=True);REVIEW.mkdir(exist_ok=True)
path=OUT/'arjun_multiview_fit_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path))
report.update({'status':'CANDIDATE_NOT_EXACT_OR_APPROVED','source':str(SOURCE.relative_to(ROOT)), 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'candidate':str(path.relative_to(ROOT)), 'reference_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'WorkingAssets/Arjun/references').glob('*.png')},'changes':['measured frontal face shape key','moustache/brow face fit','fuller crown hair','broader diagonal trouser drape','shaped split hem'],'runtime_replaced':False})
(REVIEW/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
if '--fit-only' in sys.argv: sys.exit(0)
for name,position in [('front',(0,-4,.88)),('side',(4,0,.88)),('back',(0,4,.88)),('three_quarter',(3,-4,.88))]:
 camera.location=position;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(REVIEW/(name+'.png'))
 bpy.ops.render.render(write_still=True)
scene.render.resolution_x=900;scene.render.resolution_y=900;camera.data.ortho_scale=.38
camera.location=(0,-2,1.592);camera.rotation_euler=(Vector((0,0,1.567))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'face_fitted.png');bpy.ops.render.render(write_still=True)
print('ARJUN_MULTIVIEW_FIT_READY',flush=True)
