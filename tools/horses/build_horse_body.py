"""Build an original, editable body silhouette for the village horse.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/horses/build_horse_body.py
Coordinates are authored in Blender Z-up and exported to Godot Y-up through glTF.
"""
from pathlib import Path
import bpy
from math import radians

root = Path(__file__).resolve().parents[2]
source = root / 'WorkingAssets/Horse/village_horse_body.blend'
output = root / 'assets/animals/horse/village_horse_body.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bay = bpy.data.materials.new('Bay_coat')
bay.diffuse_color = (0.085, 0.018, 0.006, 1.0)
bay.use_nodes = True
bay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = bay.diffuse_color
bay.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 0.88

parts = []
def ellipsoid(name, center, radii, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radii
    obj.rotation_euler = tuple(radians(v) for v in rotation)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    parts.append(obj)

# X is width, +Y points toward the horse's nose, Z is height.
ellipsoid('Barrel', (0, 0, 1.43), (.43, .86, .49))
ellipsoid('Deep_chest', (0, .55, 1.41), (.39, .40, .50))
ellipsoid('Haunch', (0, -.59, 1.44), (.40, .41, .47))
ellipsoid('Shoulder', (0, .56, 1.57), (.36, .34, .40), (15, 0, 0))
ellipsoid('Neck_base', (0, .78, 1.80), (.28, .37, .39), (-35, 0, 0))
ellipsoid('Neck_crest', (0, 1.00, 1.98), (.22, .32, .34), (-35, 0, 0))
ellipsoid('Head', (0, 1.27, 2.16), (.18, .30, .26), (-22, 0, 0))
ellipsoid('Jaw', (0, 1.42, 1.96), (.16, .24, .17), (-14, 0, 0))

bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = 'BayHorseBody'
remesh = body.modifiers.new('ContinuousAnatomy', 'REMESH')
remesh.mode = 'VOXEL'
remesh.voxel_size = .025
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth = body.modifiers.new('SurfaceSmoothing', 'SMOOTH')
smooth.factor = 1.4
smooth.iterations = 4
bpy.ops.object.modifier_apply(modifier=smooth.name)
for polygon in body.data.polygons: polygon.use_smooth = True
body.data.materials.append(bay)

source.parent.mkdir(parents=True, exist_ok=True)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_yup=True, use_selection=True)
print(f'HORSE BODY EXPORTED {output}')
