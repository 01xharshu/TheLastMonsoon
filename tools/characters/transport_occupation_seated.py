"""Transfer fitted lower layers from the canonical seat to the actual IK seat.

Use one body-derived displacement field for both layers so nearby fabric
moves together. The independent native audit still checks the transported fit.
"""
import json
import os
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from occupation_layered_fit import clear_body_contacts, pose, split, surface
from occupation_cloth_relax import relax
from occupation_foundation_cloth import seated_foundation
from occupation_body_triangle_fit import clear_body_triangles
from occupation_fit_constraints import ClothConstraints
from river_layer_fit import separate_layers
from occupation_native_pose import apply
from river_surface_binding import inverse_skin

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_workwear.blend'
args = [Path(value).resolve() for value in sys.argv[sys.argv.index('--') + 1:]]
sample, output = args[:2]
temporary_root = Path(tempfile.gettempdir()).resolve()
if len(args) >= 3:
    source = args[2]
if not all(path.is_relative_to(temporary_root) for path in args) or output.exists():
    raise ValueError('Expected disposable pose input and a new temporary output')

bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects['artisan_complete_MakeHuman_body']
rig = body.find_armature()
outer = bpy.data.objects['Workwear transfer study']
inner = bpy.data.objects['Street opaque foundation']
outer_key = outer.data.shape_keys.key_blocks['Study seated correction']
inner_key = inner.data.shape_keys.key_blocks['Study seated foundation']
for obj, active in ((outer, outer_key), (inner, inner_key)):
    for key in obj.data.shape_keys.key_blocks:
        key.value = float(key == active)

if len(args) == 4:
    apply(rig, json.loads(args[3].read_text()))
else:
    pose(rig, 'seated')
_, canonical_body = surface(body)
_, canonical_outer = surface(outer)
_, canonical_inner = surface(inner)
target_pose = json.loads(sample.read_text())
apply(rig, target_pose)
_, native_body = surface(body)
assert len(canonical_body) == len(native_body)

lookup = KDTree(len(canonical_body))
for index, point in enumerate(canonical_body):
    lookup.insert(point, index)
lookup.balance()
displacements = [after - before for before, after in zip(canonical_body, native_body)]


def transported(point):
    neighbors = lookup.find_range(point, .045)
    if not neighbors:
        neighbors = lookup.find_n(point, 8)
    total = 0.0
    shift = Vector()
    for _, index, distance in neighbors:
        weight = 1.0 / ((distance * distance + .000025) ** 2)
        shift += displacements[index] * weight
        total += weight
    return point + shift / total


source_coordinates = {}
for obj, key, canonical, start in (
    (inner, inner_key, canonical_inner, 0),
    (outer, outer_key, canonical_outer, 0 if len(args) == 4 else int(outer['occupation_upper_vertex_count'])),
):
    inverse = inverse_skin(rig, obj)
    originals = [point.co.copy() for point in key.data]
    source_coordinates[obj.name] = originals
    maximum = 0.0
    worst = start
    for index in range(start, len(canonical)):
        coordinate = inverse[index] @ transported(canonical[index])
        shift = coordinate - originals[index]
        if shift.length > maximum:
            maximum, worst = shift.length, index
        if len(args) == 4 and shift.length > .099:
            coordinate = originals[index] + shift.normalized() * .099
        key.data[index].co = coordinate
    print('OCCUPATION_SEAT_TRANSPORT', obj.name, 'requested_bind_mm', maximum * 1000, 'worst', tuple(originals[worst]), flush=True)
    if maximum > .10 and len(args) != 4:
        raise RuntimeError('Seated transport exceeds the 100 mm diagnostic fitting bound')
    obj.data.update()
    obj.update_tag(refresh={'DATA'})
bpy.context.view_layer.update()

volume, skin_points, skin_faces = surface(body, volume=True, with_faces=True)


def clean_component(indices, name, support, gap):
    component = split(outer, indices, name, rig)
    key = component.shape_key_add(name='Native seat fit')
    for index, original in enumerate(indices):
        key.data[index].co = outer_key.data[original].co
    key.value = 1.0
    bpy.context.view_layer.update()
    _, _, faces = surface(component, with_faces=True)
    constraints = ClothConstraints(faces, volume, (skin_points, skin_faces))
    original_coordinates = [point.co.copy() for point in key.data]
    inverse = inverse_skin(rig, component)
    forward = [matrix.inverted() for matrix in inverse]

    def limit_point(index, current, proposed):
        delta = inverse[index] @ proposed - original_coordinates[index]
        if delta.length > .0349:
            proposed = forward[index] @ (original_coordinates[index] + delta.normalized() * .0349)
        if len(args) == 4:
            authored = source_coordinates[outer.name][indices[index]]
            total = inverse[index] @ proposed - authored
            if total.length > .0999:
                return forward[index] @ (authored + total.normalized() * .0999)
        return proposed

    clear_body_contacts(rig, component, key, volume, limit_point)
    clear_body_triangles(rig, component, key, skin_points, skin_faces, limit_point)
    relax(rig, component, volume, key, limit_point=limit_point,
          candidate_clear=constraints.body_clear)
    support_tree, support_points, support_faces = surface(support, with_faces=True)
    separate_layers(rig, component, key, support_points, support_faces, support_tree,
                    gap=.006, reserve_margin=False, limit_point=limit_point,
                    slide_contacts=True, candidate_clear=constraints, minimum_gap=gap,
                    allow_compression=gap > 0)
    maximum_cleanup = max((point.co - original).length
                          for point, original in zip(key.data, original_coordinates))
    print('OCCUPATION_SEAT_CLEANUP_MM', name, maximum_cleanup * 1000, flush=True)
    if maximum_cleanup > .035:
        raise RuntimeError(name + ' cleanup exceeds 35 mm')
    for index, original in enumerate(indices):
        outer_key.data[original].co = key.data[index].co
    return component


if len(args) == 4 and os.environ.get('TLM_OCCUPATION_SIM_LOW_FOUNDATION') == '1':
    def low_seat_pose(armature, label):
        if label == 'idle':
            pose(armature, 'idle')
        else:
            apply(armature, target_pose)

    seated_foundation(rig, body, inner, inner_key, low_seat_pose, animate_location=True)
    maximum = max((point.co - original).length for point, original in
                  zip(inner_key.data, source_coordinates[inner.name]))
    print('OCCUPATION_LOW_SEAT_FOUNDATION_SIM_MM', maximum * 1000, flush=True)
    if maximum > .10:
        raise RuntimeError('Low-seat foundation simulation exceeds 100 mm')

inner_inverse = inverse_skin(rig, inner)
inner_original = [point.co.copy() for point in inner_key.data]
inner_forward = [matrix.inverted() for matrix in inner_inverse]


def limit_inner(index, current, proposed):
    delta = inner_inverse[index] @ proposed - inner_original[index]
    if delta.length > .015:
        proposed = inner_forward[index] @ (inner_original[index] + delta.normalized() * .015)
    if len(args) == 4:
        authored = source_coordinates[inner.name][index]
        total = inner_inverse[index] @ proposed - authored
        if total.length > .0999:
            return inner_forward[index] @ (authored + total.normalized() * .0999)
    return proposed


clear_body_triangles(rig, inner, inner_key, skin_points, skin_faces, limit_inner)
# Compression in the posed seat may narrow the canonical 3 mm construction gap.
upper_count = int(outer['occupation_upper_vertex_count'])
trousers = clean_component(list(range(upper_count, len(outer.data.vertices))),
                            'Native seat trousers', inner, .0015)
shirt = clean_component(list(range(upper_count)), 'Native seat shirt', trousers, 0.0)
bpy.data.objects.remove(shirt, do_unlink=True)
bpy.data.objects.remove(trousers, do_unlink=True)
outer_key.value = 0
inner_key.value = 0
pose(rig, 'idle')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output))
