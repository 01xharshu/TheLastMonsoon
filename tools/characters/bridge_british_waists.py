"""Add an editable, rigged bodice-to-skirt transition to one British pair.
Blender --background --python tools/characters/bridge_british_waists.py -- private
"""
import bpy
import math
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
rank = sys.argv[sys.argv.index('--')+1]
source = root / f'WorkingAssets/NPCs/british/{rank}_pair/{rank}_pair_mpfb_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig = bpy.data.objects['Companion_game_engine_rig']
skirt = bpy.data.objects['Companion gathered skirt']
existing = bpy.data.objects.get('Companion fitted waist transition')
if existing:
    bpy.data.objects.remove(existing, do_unlink=True)
scale = max(v.co.z for v in skirt.data.vertices) / .82
sides = 72
levels = []
for t in [0, .20, .40, .60, .80, 1.0]:
    # Lower edge matches the gathered skirt. Upper edge tucks into the
    # fitted bodice instead of leaving an open annulus behind the waist.
    smooth = t*t*(3-2*t)
    levels.append(((.82+.18*t)*scale,
                   (.17-.065*smooth)*scale,
                   (.156-.071*smooth)*scale,
                   -.0625*smooth*scale))
vertices = []
for z, rx, ry, center_y in levels:
    for j in range(sides):
        theta = math.tau*j/sides
        vertices.append((rx*math.cos(theta), center_y+ry*math.sin(theta), z))
faces = []
for row in range(len(levels)-1):
    for j in range(sides):
        nxt = (j+1)%sides
        faces.append((row*sides+j,row*sides+nxt,(row+1)*sides+nxt,(row+1)*sides+j))
mesh = bpy.data.meshes.new('Companion fitted waist transition mesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
obj = bpy.data.objects.new('Companion fitted waist transition', mesh)
bpy.context.scene.collection.objects.link(obj)
obj.parent = rig
obj.data.materials.append(skirt.data.materials[0])
pelvis = obj.vertex_groups.new(name='pelvis')
spine = obj.vertex_groups.new(name='spine_01')
for row in range(len(levels)):
    indices=list(range(row*sides,(row+1)*sides))
    upper=max(0.0,min(0.75,(row/5-.30)*1.1))
    pelvis.add(indices,1.0-upper,'REPLACE')
    if upper:
        spine.add(indices,upper,'REPLACE')
mod=obj.modifiers.new('Rig deformation','ARMATURE')
mod.object=rig
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('BRITISH_WAIST_BRIDGE',rank,'rows',len(levels),'vertices',len(vertices))
