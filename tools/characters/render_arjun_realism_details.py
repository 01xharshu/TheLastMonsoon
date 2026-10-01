"""Close-up evidence for the separate material study."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/characters/arjun/reference_fit/material_realism_2026-10-01'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/Arjun/reference_fit/arjun_material_realism_candidate.blend'))
s=bpy.context.scene;c=s.camera;s.render.resolution_x=900;s.render.resolution_y=900;s.cycles.samples=48
for name,target,scale in [('face_detail',(0,0,1.60),.40),('cloth_detail',(0,0,1.16),.55),('boot_detail',(.195,0,.16),.36)]:
 c.data.ortho_scale=scale;c.location=Vector(target)+Vector((.16,-2,.03));c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
