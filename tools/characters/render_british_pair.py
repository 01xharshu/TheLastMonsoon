"""Render an isolated British NPC Blender candidate for visual review."""
import bpy
import sys
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
name = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "private"
source = root / f"WorkingAssets/NPCs/british/{name}_pair/{name}_pair_mpfb_candidate.blend"
bpy.ops.wm.open_mainfile(filepath=str(source))
rigs = [o for o in bpy.data.objects if o.type == "ARMATURE"]

world = bpy.context.scene.world or bpy.data.worlds.new("review world")
bpy.context.scene.world = world
world.color = (.7, .7, .7)

def target(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat('-Z', 'Y').to_euler()

cam_data = bpy.data.cameras.new("Review orthographic")
cam = bpy.data.objects.new("Review orthographic", cam_data)
bpy.context.collection.objects.link(cam)
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 2.45
bpy.context.scene.camera = cam

for loc, energy, size in [((-3, -4, 5), 650, 4), ((3, -2, 3), 350, 3)]:
    data = bpy.data.lights.new("Review softbox", 'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    light = bpy.data.objects.new("Review softbox", data)
    bpy.context.collection.objects.link(light)
    light.location = loc
    target(light, (0, 0, 1))

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 1200
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
out = root / 'docs/characters/british/candidates'
out.mkdir(parents=True, exist_ok=True)
for view, loc in [('front', (0, -6, 1.05)), ('side', (6, 0, 1.05)), ('back', (0, 6, 1.05))]:
    for rig in rigs:
        is_male = name.capitalize() in rig.name
        rig.location.x = 0 if view == 'side' else (-.85 if is_male else .85)
        rig.location.y = (-.70 if is_male else .70) if view == 'side' else 0
    cam.location = loc
    target(cam, (0, 0, .94))
    scene.render.filepath = str(out / f'{name}_pair_{view}.png')
    bpy.ops.render.render(write_still=True)
