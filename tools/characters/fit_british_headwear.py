"""Fit existing headwear to the evaluated MPFB scalp; preserve head skinning."""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
rank = sys.argv[sys.argv.index('--') + 1]
source = root / f'WorkingAssets/NPCs/british/{rank}_pair/{rank}_pair_mpfb_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
results = []
for slug in (rank.capitalize(), 'Companion'):
    rig = bpy.data.objects[slug + '_game_engine_rig']
    parts = [o for o in bpy.data.objects if o.parent == rig and o.type == 'MESH'
             and any(word in o.name.lower() for word in ('forage cap', 'cap band', 'cap visor', 'bonnet', 'top hat'))]
    if not parts:
        continue
    crown = next(o for o in parts if any(word in o.name.lower() for word in ('forage cap', 'bonnet crown', 'top hat')) and 'visor' not in o.name.lower())
    old_pose = rig.data.pose_position
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    body = bpy.data.objects[slug + '_MPFB_body'].evaluated_get(bpy.context.evaluated_depsgraph_get())
    top = max(v.co.z for v in body.data.vertices)
    scalp = [v.co for v in body.data.vertices if v.co.z > top - 0.06]
    lo = Vector(tuple(min(v[i] for v in scalp) for i in range(3)))
    hi = Vector(tuple(max(v[i] for v in scalp) for i in range(3)))
    target = (lo + hi) * 0.5
    desired_rx = (hi.x - lo.x) * 0.5 + 0.008
    desired_ry = (hi.y - lo.y) * 0.5 + 0.008
    points = [crown.matrix_basis @ v.co for v in crown.data.vertices]
    old_lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
    old_hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
    center = (old_lo + old_hi) * 0.5
    fit_points = points
    if 'top hat' in crown.name.lower():
        # Fit the cylinder to the head; the brim deliberately extends beyond it.
        span = old_hi.z - old_lo.z
        fit_points = [p for p in points if old_lo.z + span * 0.15 < p.z < old_lo.z + span * 0.98]
    sx = desired_rx / ((max(p.x for p in fit_points) - min(p.x for p in fit_points)) * 0.5)
    sy = desired_ry / ((max(p.y for p in fit_points) - min(p.y for p in fit_points)) * 0.5)
    base = top - (0.045 if slug == 'Companion' else 0.055)
    # The top hat retains its silhouette; shallow caps sit close to the scalp.
    height = 0.17 if 'top hat' in crown.name.lower() else max(0.065, top + 0.025 - base)
    sz = height / (old_hi.z - old_lo.z)
    for obj in parts:
        inverse = obj.matrix_basis.inverted()
        for vertex in obj.data.vertices:
            point = obj.matrix_basis @ vertex.co
            point.x = target.x + (point.x - center.x) * sx
            point.y = target.y + (point.y - center.y) * sy
            point.z = base + (point.z - old_lo.z) * sz
            vertex.co = inverse @ point
        obj.vertex_groups.clear()
        obj.vertex_groups.new(name='head').add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    rig.data.pose_position = old_pose
    results.append({'actor': slug, 'parts': [o.name for o in parts], 'scalp_top_m': top,
                    'crown_width_m': desired_rx * 2, 'crown_depth_m': desired_ry * 2,
                    'base_m': base, 'head_weight': 1.0})
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source))
out = root / f'docs/characters/british/candidates/{rank}_headwear_fit.json'
out.write_text(json.dumps({'rank': rank, 'fits': results, 'visual_approved': False}, indent=2) + '\n')
print('BRITISH_HEADWEAR_FIT', json.dumps(results))
