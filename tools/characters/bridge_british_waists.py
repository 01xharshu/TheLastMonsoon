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
top_z = max(v.co.z for v in skirt.data.vertices)
scale = top_z / .82
top_ring = [v.co.copy() for v in skirt.data.vertices if abs(v.co.z-top_z)<0.0001]
sides = len(top_ring)
assert sides in (72,144), (rank,sides)
vertices = []
for row, t in enumerate([0, .20, .40, .60, .80, 1.0]):
    # Gather most of the skirt fullness immediately above its top edge,
    # leaving the upper transition tucked close to the bodice silhouette.
    smooth = 1.0-(1.0-t)**3
    for j, bottom in enumerate(top_ring):
        theta = math.tau*j/sides
        upper_x = .105*scale*math.cos(theta)
        upper_y = (-.0625+.085*math.sin(theta))*scale
        vertices.append((bottom.x*(1-smooth)+upper_x*smooth,
                         bottom.y*(1-smooth)+upper_y*smooth,
                         top_z+.18*scale*t))
faces = []
for row in range(5):
    for j in range(sides):
        nxt = (j+1)%sides
        faces.append((row*sides+j,row*sides+nxt,(row+1)*sides+nxt,(row+1)*sides+j))
mesh = bpy.data.meshes.new('Companion fitted waist transition mesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
for face in mesh.polygons:
    face.use_smooth = True
obj = bpy.data.objects.new('Companion fitted waist transition', mesh)
bpy.context.scene.collection.objects.link(obj)
obj.parent = rig
obj.data.materials.append(skirt.data.materials[0])
pelvis = obj.vertex_groups.new(name='pelvis')
spine = obj.vertex_groups.new(name='spine_01')
for row in range(6):
    indices=list(range(row*sides,(row+1)*sides))
    upper=max(0.0,min(0.75,(row/5-.30)*1.1))
    pelvis.add(indices,1.0-upper,'REPLACE')
    if upper:
        spine.add(indices,upper,'REPLACE')
mod=obj.modifiers.new('Rig deformation','ARMATURE')
mod.object=rig
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('BRITISH_WAIST_BRIDGE',rank,'rows',6,'vertices',len(vertices))
