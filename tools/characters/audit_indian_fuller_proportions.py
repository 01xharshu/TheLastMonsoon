"""Measure localized fuller adult body changes against the retained sources.

This verifies identity/shape retention, not clothing or visual approval.
"""
import json
from pathlib import Path
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]

def sample(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    rig.data.pose_position = 'REST'
    for modifier in body.modifiers:
        if modifier.type in ('ARMATURE', 'MASK'):
            modifier.show_viewport = False
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    points = np.array([tuple(body.matrix_world @ v.co) for v in mesh.vertices])
    evaluated.to_mesh_clear()
    group = body.vertex_groups['body'].index
    human = np.array([any(g.group == group and g.weight > .5 for g in v.groups) for v in body.data.vertices])
    return points, human, len(body.data.vertices)

for number in range(1, 7):
    identity = f'female_{number:02}'
    folder = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / identity
    tailored = folder / 'tailored_deep_vneck_study.blend'
    source = tailored if tailored.is_file() else folder / 'candidate.blend'
    study = folder / ('tailored_fuller_study.blend' if tailored.is_file() else 'fuller_body_study.blend')
    original, human, count = sample(source)
    fuller, current_human, current_count = sample(study)
    if count != 19158 or current_count != count or not np.array_equal(human, current_human):
        raise RuntimeError(identity + ': complete source topology changed')
    delta = fuller - original
    lengths = np.linalg.norm(delta, axis=1)
    head = human & (original[:, 2] > 1.27)
    bust = human & (original[:, 2] > 1.02) & (original[:, 2] < 1.20) & (original[:, 1] < -.04)
    rear = human & (original[:, 2] > .69) & (original[:, 2] < .94) & (original[:, 1] > .055)
    front_mm = float((-delta[bust, 1]).max() * 1000)
    rear_mm = float(delta[rear, 1].max() * 1000)
    head_mm = float(lengths[head].max() * 1000)
    if head_mm > .001 or front_mm < .1 or rear_mm < .1:
        raise RuntimeError(f'{identity}: unintended head change or no bust/rear increase')
    print('FULLER_PROPORTIONS', json.dumps(dict(identity=identity, complete_body_vertices=count,
          head_change_mm=head_mm, bust_forward_max_mm=front_mm, rear_backward_max_mm=rear_mm,
          max_change_mm=float(lengths.max() * 1000))), flush=True)
