"""Second measured frontal fit on the repaired surface candidate; no runtime export."""
import bpy,sys,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
import fit_arjun_reference_face as fit
OUT=ROOT/'WorkingAssets/Arjun/reference_fit';REVIEW=ROOT/'docs/characters/arjun/reference_fit'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'arjun_multiview_surface_candidate.blend'))
fit.FIT=OUT/'reference_face_residual_fit.json'
fit.calibrate('face_landmarks_surface.json')
body=bpy.data.objects['Arjun_MakeHuman_Body'];report=fit.apply_reference_fit(body)
data=json.loads(fit.FIT.read_text());centres=np.array([c['source_local'] for c in data['controls']]);deltas=np.array([c['delta_local'] for c in data['controls']])
weights=np.linalg.solve(fit.gaussian(centres,centres,data['kernel_width_m'])+np.eye(len(centres))*data['regularization'],deltas)
for name in ['Arjun_Eyebrows','Arjun_Detail_Soft black hair']:
 obj=bpy.data.objects.get(name)
 if not obj:continue
 points=np.array([v.co[:] for v in obj.data.vertices]);moves=fit.gaussian(points,centres,data['kernel_width_m'])@weights*data['strength']
 for v,move in zip(obj.data.vertices,moves):v.co+=Vector(move)
# Close the polar crown seam without a degenerate pointed tuft.
for name in ['Arjun_Reference_WavyCrown','Arjun_Reference_WavyLocks']:
 obj=bpy.data.objects.get(name)
 if obj:
  for v in obj.data.vertices:
   radius=(v.co.x*v.co.x+(v.co.y+.032)**2)**.5
   if radius<.015:v.co.z=min(v.co.z,1.745-.004*radius/.015)
scene=bpy.context.scene;camera=scene.camera
source=OUT/'arjun_multiview_residual_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
camera.data.ortho_scale=.38;scene.render.resolution_x=900;scene.render.resolution_y=900
camera.location=(0,-2,1.592);camera.rotation_euler=(Vector((0,0,1.567))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(REVIEW/'face_residual.png');bpy.ops.render.render(write_still=True)
scene.render.resolution_x=700;scene.render.resolution_y=950;camera.data.ortho_scale=1.92
for name,pos in [('front_residual',(0,-4,.88)),('side_residual',(4,0,.88)),('back_residual',(0,4,.88)),('three_quarter_residual',(3,-4,.88))]:
 camera.location=pos;camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(REVIEW/(name+'.png'));bpy.ops.render.render(write_still=True)
report.update({'source':str(source.relative_to(ROOT)), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'runtime_replaced':False,'status':'REFERENCE_LIKENESS_CANDIDATE_NOT_EXACT'})
(REVIEW/'residual_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARJUN_RESIDUAL_FIT_RENDERED')
