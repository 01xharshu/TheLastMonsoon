"""Fit three lower-cloth motion corrections against replayed Godot poses."""
import json
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from occupation_body_triangle_fit import clear_body_triangles
from occupation_cloth_relax import relax
from occupation_fit_constraints import ClothConstraints
from occupation_layered_fit import clear_body_contacts, pose, split, surface
from occupation_native_pose import apply
from river_layer_fit import separate_layers
from river_surface_binding import inverse_skin

arguments = sys.argv[sys.argv.index('--') + 1:]
source, samples, output = [Path(arg).resolve() for arg in arguments[:3]]
merge_seated = "--merge-seated" in arguments[3:]
extra_samples = [arg for arg in arguments[3:] if arg != "--merge-seated"]
merged_deltas = {}
temp_root = Path(tempfile.gettempdir()).resolve()
if not all(path.is_relative_to(temp_root) for path in (source, samples, output)) or output.exists():
    raise ValueError('Motion fitting expects disposable source, samples and output')
bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects['artisan_complete_MakeHuman_body']
rig = body.find_armature()
outer = bpy.data.objects['Workwear transfer study']
inner = bpy.data.objects['Street opaque foundation']
upper_count = int(outer['occupation_upper_vertex_count'])
shirt_ids = list(range(upper_count))
trouser_ids = list(range(upper_count, len(outer.data.vertices)))


def blended_coordinates(obj, indices, weights):
    keys = obj.data.shape_keys.key_blocks
    result = []
    target_name = "Study seated foundation" if obj == inner else "Study seated correction"
    adjustments = merged_deltas.get((obj.name, target_name), {})
    for index in indices:
        base = keys[0].data[index].co
        value = base.copy()
        for key in list(keys)[1:]:
            value += (key.data[index].co - base) * weights.get(key.name, 0)
        result.append(value + adjustments.get(index, Vector()))
    return result


def correction_limit(rig, cloth, original):
    inverse = inverse_skin(rig, cloth)
    forward = [matrix.inverted() for matrix in inverse]

    maximum = .034 if merge_seated else .020

    def limit(index, current, proposed):
        offset = inverse[index] @ proposed - original[index]
        if offset.length > maximum:
            return forward[index] @ (original[index] + offset.normalized() * maximum)
        return proposed

    return limit


def fit_layer(cloth, key, original, volume, skin, support=None):
    _, _, faces = surface(cloth, with_faces=True)
    constraints = ClothConstraints(faces, volume, skin)
    limit = correction_limit(rig, cloth, original)
    clear_body_contacts(rig, cloth, key, volume, limit)
    clear_body_triangles(rig, cloth, key, *skin, limit)
    relax(rig, cloth, volume, key, limit_point=limit, candidate_clear=constraints.body_clear)
    if support is not None:
        tree, points, faces = surface(support, with_faces=True)
        separate_layers(rig, cloth, key, points, faces, tree, gap=.004,
                        reserve_margin=False, limit_point=limit,
                        slide_contacts=True, candidate_clear=constraints)


def write_delta(obj, key_name, indices, before, after, strength):
    deltas = [(last - first) / strength for first, last in zip(before, after)]
    if extra_samples:
        # Reserve the measured import quantization margin on local fabric moves.
        deltas = [delta + delta.normalized() * .00015 if delta.length > .001 else delta
                  for delta in deltas]
    maximum = max(delta.length for delta in deltas)
    if maximum > .035:
        raise RuntimeError('Motion corrective exceeds 35 mm: ' + key_name)
    if maximum < .00001:
        print('OCCUPATION_MOTION_KEY_UNNEEDED', key_name, flush=True)
        return
    if merge_seated:
        target_name = "Study seated foundation" if obj == inner else "Study seated correction"
        combined = merged_deltas.setdefault((obj.name, target_name), {})
        for index, delta in zip(indices, deltas):
            if delta.length_squared < 1e-10:
                continue
            updated = combined.get(index, Vector()) + delta
            if updated.length > .035:
                updated = updated.normalized() * .035
            combined[index] = updated
        print('OCCUPATION_SEATED_SAMPLE', key_name, 'bind_mm', maximum * 1000, flush=True)
        return
    keys = obj.data.shape_keys.key_blocks
    target = keys.get(key_name) or obj.shape_key_add(name=key_name)
    for index, delta in zip(indices, deltas):
        target.data[index].co += delta
    target.value = 0
    print('OCCUPATION_MOTION_KEY', key_name, 'bind_mm', maximum * 1000, flush=True)



jobs = ([(name, '') for name in extra_samples] if extra_samples else
        [('walk_03', 'reverse walk'), ('repair_03', 'sit midpoint'), ('rise_03', 'rise midpoint')])
processed = set()
for label, phase in jobs:
    data = json.loads((samples / (label + '.json')).read_text())
    if not phase:
        if data['pose'] == 'walk':
            phase = f"gait {round(data['walk_phase'] * 100000)} {round(data['walk_blend'] * 1000)}"
        elif data['pose'] == 'village_repair':
            phase = f"repair-entry {round(data['age'] * 1000)}"
        elif data['pose'] in ('repair', 'rise'):
            kind = 'sit' if data['pose'] == 'repair' else 'rise'
            phase = f"{kind} {round(data['age'] * 1000)}"
        else:
            raise ValueError('Unsupported motion refinement sample: ' + label)
    if phase in processed:
        continue
    processed.add(phase)
    apply(rig, data)
    volume, skin_points, skin_faces = surface(body, volume=True, with_faces=True)
    skin = skin_points, skin_faces
    inner_weights = next(entry['morphs'] for entry in data['meshes'] if 'opaque foundation' in entry['name'])
    outer_weights = next(entry['morphs'] for entry in data['meshes'] if 'cotton trousers' in entry['name'])
    inner_ids = list(range(len(inner.data.vertices)))
    inner_before = blended_coordinates(inner, inner_ids, inner_weights)
    outer_before = blended_coordinates(outer, trouser_ids, outer_weights)
    if merge_seated and min(inner_weights['Study seated foundation'], outer_weights['Study seated correction']) < .99:
        raise ValueError('Settled repair fit requires the fully seated correction: ' + label)
    inner_strength = inner_weights['Study reverse walk foundation'] if phase == 'reverse walk' else 1.0
    outer_strength = outer_weights['Study reverse walk correction'] if phase == 'reverse walk' else 1.0
    if min(inner_strength, outer_strength) < .25:
        raise RuntimeError('Motion sample does not have sufficient corrective weight: ' + label)

    for key in inner.data.shape_keys.key_blocks:
        key.value = 0
    inner_work = inner.shape_key_add(name='Temporary phase fit')
    for point, coordinate in zip(inner_work.data, inner_before):
        point.co = coordinate
    inner_work.value = 1
    trousers = split(outer, trouser_ids, 'Motion trousers ' + phase, rig)
    trouser_work = trousers.shape_key_add(name='Temporary phase fit')
    for point, coordinate in zip(trouser_work.data, outer_before):
        point.co = coordinate
    trouser_work.value = 1
    bpy.context.view_layer.update()
    fit_layer(inner, inner_work, inner_before, volume, skin)
    fit_layer(trousers, trouser_work, outer_before, volume, skin, inner)
    if extra_samples:
        shirt_before = blended_coordinates(outer, shirt_ids, outer_weights)
        shirt = split(outer, shirt_ids, 'Motion shirt ' + phase, rig)
        shirt_work = shirt.shape_key_add(name='Temporary phase fit')
        for point, coordinate in zip(shirt_work.data, shirt_before):
            point.co = coordinate
        shirt_work.value = 1
        bpy.context.view_layer.update()
        fit_layer(shirt, shirt_work, shirt_before, volume, skin, trousers)
        shirt_after = [point.co.copy() for point in shirt_work.data]
        bpy.data.objects.remove(shirt, do_unlink=True)
        write_delta(outer, 'Study ' + phase + ' correction', shirt_ids, shirt_before, shirt_after, 1.0)
    inner_after = [point.co.copy() for point in inner_work.data]
    outer_after = [point.co.copy() for point in trouser_work.data]
    inner.shape_key_remove(inner_work)
    bpy.data.objects.remove(trousers, do_unlink=True)
    write_delta(inner, 'Study ' + phase + ' foundation', inner_ids, inner_before, inner_after, inner_strength)
    write_delta(outer, 'Study ' + phase + ' correction', trouser_ids, outer_before, outer_after, outer_strength)

for (name, key_name), deltas in merged_deltas.items():
    key = bpy.data.objects[name].data.shape_keys.key_blocks[key_name]
    for index, delta in deltas.items():
        key.data[index].co += delta

pose(rig, 'idle')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output))
