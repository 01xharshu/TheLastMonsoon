"""Adapt the retained clean adult blouse/panels to another complete MPFB body.

Only clothing is transferred; the target body, identity, rig and physique stay
unchanged. A separate, previously nonexistent study output is required.
"""
import argparse
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body
from purpose_cloth_volume import VolumeSurface
from river_coherent_cloth import fit_key

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--identity', required=True, choices=[f'female_{n:02}' for n in range(1, 7)])
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
folder = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / args.identity
source = folder / 'fuller_body_study.blend'
template = ROOT / 'WorkingAssets/NPCs/indian_body_candidates/female_04/tailored_fuller_study.blend'
output = args.output.expanduser().resolve()
if not source.is_file() or output.exists() or output == source.resolve():
    raise ValueError('Requires an existing fuller source and a separate new output')
names = ['Opaque fitted bra and thong foundation', 'Street coherent cotton blouse and pallu',
         'Street sari front pallu', 'Street sari back tail']

def setup():
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    rig.data.pose_position = 'REST'
    for modifier in body.modifiers:
        if modifier.type == 'MASK':
            modifier.show_viewport = False
    bpy.context.view_layer.update()
    return body, rig

def points_of(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    points = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    return points

bpy.ops.wm.open_mainfile(filepath=str(template))
body, rig = setup()
template_points = points_of(body)
human_group = body.vertex_groups['body'].index
human = [v.index for v in body.data.vertices if any(g.group == human_group and g.weight > .5 for g in v.groups)]
tree = KDTree(len(human))
for index in human:
    tree.insert(template_points[index], index)
tree.balance()
cloth_points = {name: points_of(bpy.data.objects[name]) for name in names}

bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
body, rig = setup()
if body.get('body_profile') != args.identity or len(body.data.vertices) != len(template_points):
    raise RuntimeError('Target must retain its matching complete MPFB body')
target_points = points_of(body)
delta = [new - old for new, old in zip(target_points, template_points)]
old_upper = bpy.data.objects['Street coherent cotton blouse and pallu']
colors = old_upper.data.color_attributes['StreetCotton']
palette = {}
for item in colors.data:
    color = tuple(round(channel, 4) for channel in item.color)
    palette[color] = palette.get(color, 0) + 1
cotton_color = max(palette, key=palette.get)
for name in names:
    old = bpy.data.objects.get(name)
    if old:
        old.name = 'Retained pre-tailoring ' + name
        old['street_source_only'] = True
        old.hide_render = True
        old.hide_set(True)
existing_objects = set(bpy.data.objects)
with bpy.data.libraries.load(str(template), link=False) as (available, loaded):
    loaded.objects = list(names)
for name, garment in zip(names, loaded.objects):
    if garment is None:
        raise RuntimeError('Missing template garment: ' + name)
    bpy.context.collection.objects.link(garment)
    garment.name = name
    original_world = garment.matrix_world.copy()
    garment.parent = rig
    garment.matrix_world = original_world
    for modifier in garment.modifiers:
        if modifier.type == 'ARMATURE':
            modifier.object = rig
    garment.shape_key_clear()
    inverse = garment.matrix_world.inverted()
    if len(garment.data.vertices) != len(cloth_points[name]):
        raise RuntimeError('Template garment evaluation changed topology')
    for vertex, point in zip(garment.data.vertices, cloth_points[name]):
        nearest = tree.find_n(point, 3)
        weights = [1.0 / max(distance, .001) ** 2 for _, _, distance in nearest]
        shift = sum((delta[index] * weight for (_, index, _), weight in zip(nearest, weights)), Vector()) / sum(weights)
        vertex.co = inverse @ (point + shift)
    if name == 'Street coherent cotton blouse and pallu':
        colors = garment.data.color_attributes.get('StreetCotton')
        if colors:
            for item in colors.data:
                item.color = cotton_color
    garment['tailoring_source'] = str(template.relative_to(ROOT))
    garment['approval'] = 'Unapproved transferred fabric; fit, layers and motion require review'
    garment.data.update()
# Remove only dependency armatures imported with these garments, after all
# garments have been rebound to the unchanged target rig.
for obj in list(bpy.data.objects):
    if obj not in existing_objects and obj.type == 'ARMATURE' and obj != rig:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.context.view_layer.update()
mesh = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
mesh.calc_loop_triangles()
group = body.vertex_groups['body'].index
human = {v.index for v in body.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)}
faces = [tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)]
volume = VolumeSurface.FromPolygons(target_points, faces, all_triangles=True, strict=True)
body.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
for name in names[:2]:
    garment = bpy.data.objects[name]
    key = garment.shape_key_add(name='Basis')
    correction = fit_key(rig, garment, volume, key, reset_key=False, minimum_clearance_m=.006)
    if correction > .06:
        raise RuntimeError('Transferred garment exceeds bounded60mm fit: ' + name)
    for vertex, fitted in zip(garment.data.vertices, key.data):
        vertex.co = fitted.co
    print('SHARED_TAILORING_FIT', args.identity, name, correction * 1000, flush=True)
if max((a-b).length for a,b in zip(points_of(body),target_points)) > .000001:
    raise RuntimeError('Clothing transfer altered the target body')
retain_complete_body(body)
# Keep the editable study portable when moved from temporary authoring paths.
for obj in bpy.data.objects:
    if obj.type != 'MESH' or obj.get('street_source_only',False):
        continue
    for material in obj.data.materials:
        if not material or not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image and node.image.source == 'FILE' and not node.image.packed_file:
                image_path=Path(bpy.path.abspath(node.image.filepath))
                if not image_path.is_file():
                    raise FileNotFoundError('Missing active garment/body image: '+str(image_path))
                node.image.pack()
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('SHARED_TAILORING_STUDY', args.identity, output, flush=True)
