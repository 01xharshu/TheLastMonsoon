"""Export the complete packed occupation candidate without baking away morphs.

Run in Blender with -- --output /OS/temp/candidate.glb. The source is read only;
component splitting happens in memory and preserves vertex weights and keys.
"""
import argparse
from pathlib import Path
import sys
import tempfile
import bpy

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=ROOT / 'WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_workwear.blend')
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
output = args.output.resolve()
if not output.is_relative_to(Path(tempfile.gettempdir()).resolve()) or output.exists():
    raise RuntimeError('Initial export must be a new OS temporary GLB')
bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()))
source = bpy.data.objects['Workwear transfer study']
rig = source.find_armature()
assert rig is not None
upper = int(source['occupation_upper_vertex_count'])
keys = source.data.shape_keys.key_blocks


def component(ids, name):
    remap = {old: new for new, old in enumerate(ids)}
    polygons = [p for p in source.data.polygons if all(i in remap for i in p.vertices)]
    mesh = bpy.data.meshes.new(name + ' export')
    mesh.from_pydata([keys[0].data[i].co.copy() for i in ids], [],
                     [tuple(remap[i] for i in p.vertices) for p in polygons])
    mesh.update()
    # The split mesh otherwise loses cloth smoothing and renders as rigid facets.
    for polygon in mesh.polygons:polygon.use_smooth = True
    obj = bpy.data.objects.new(name + ' export', mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    obj.matrix_world = source.matrix_world.copy()
    for new, old in enumerate(ids):
        for assignment in source.data.vertices[old].groups:
            label = source.vertex_groups[assignment.group].name
            group = obj.vertex_groups.get(label) or obj.vertex_groups.new(name=label)
            group.add([new], assignment.weight, 'REPLACE')
    obj.modifiers.new('Original MPFB rig', 'ARMATURE').object = rig
    for key in keys:
        target = obj.shape_key_add(name=key.name)
        for new, old in enumerate(ids):
            target.data[new].co = key.data[old].co
        target.value = 0
    for source_uv in source.data.uv_layers:
        target_uv = mesh.uv_layers.new(name=source_uv.name)
        for target_poly, source_poly in zip(mesh.polygons, polygons):
            for tl, sl in zip(target_poly.loop_indices, source_poly.loop_indices):
                target_uv.data[tl].uv = source_uv.data[sl].uv
    material = bpy.data.materials.new(name + ' opaque cotton')
    material.diffuse_color = (.34, .26, .16, 1) if 'trousers' in name else (.65, .53, .34, 1)
    material.use_nodes = True
    material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = material.diffuse_color
    material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .88
    mesh.materials.append(material)
    return obj

shirt = component(list(range(upper)), 'Activity cotton shirt')
trousers = component(list(range(upper, len(source.data.vertices))), 'Activity cotton trousers')
visible = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.hide_render and not o.hide_get() and o != source]
selected = list(dict.fromkeys([rig, shirt, trousers] + visible))
assert bpy.data.objects['artisan_complete_MakeHuman_body'] in selected
assert bpy.data.objects['Street opaque foundation'] in selected
assert len(bpy.data.objects['artisan_complete_MakeHuman_body'].data.vertices) == 14517
for obj in bpy.context.scene.objects:
    obj.select_set(False)
for obj in selected:
    obj.hide_set(False)
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
                          export_animations=False, export_morph=True,
                          export_skins=True, export_all_influences=True,
                          export_cameras=False, export_lights=False)
print('OCCUPATION_GLB_EXPORTED', len(selected), 'objects', len(shirt.data.vertices), len(trousers.data.vertices), 'cloth vertices')
