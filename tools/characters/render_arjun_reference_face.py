import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/Arjun/candidate/arjun_reference_candidate.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
camera=scene.camera
camera.data.type='ORTHO';camera.data.ortho_scale=.38
camera.location=(0,-2,1.592)
camera.rotation_euler=(Vector((0,0,1.567))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(ROOT/'WorkingAssets/Arjun/reference_fit/face_baseline.png')
bpy.ops.render.render(write_still=True)
