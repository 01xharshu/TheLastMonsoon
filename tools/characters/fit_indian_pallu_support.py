"""Keep the front sari panel supported by the torso as the arm sweeps.

Only an isolated adult study garment is changed. Human topology and coordinates
remain intact. Re-export and native contact validation are required afterward.
"""
import argparse
from pathlib import Path
import sys

import bpy

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--identity', required=True)
parser.add_argument('--source', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
source = args.source.resolve()
if not source.is_relative_to(ROOT / 'WorkingAssets/NPCs/indian_body_candidates'):
    raise ValueError('An isolated editable study is required')
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and 'MakeHuman_body' in obj.name)
if body.get('body_profile') != args.identity:
    raise ValueError('Mismatched body identity')
panel = bpy.data.objects['Street sari front pallu']
torso = panel.vertex_groups.get('spine_03') or panel.vertex_groups.new(name='spine_03')
arm_groups = {group.index for group in panel.vertex_groups
              if group.name.startswith(('upperarm_', 'lowerarm_', 'hand_', 'thumb_', 'index_', 'middle_', 'ring_', 'pinky_'))}
changed = 0
for vertex in panel.data.vertices:
    weight = sum(group.weight for group in vertex.groups if group.group in arm_groups)
    if weight <= 0:
        continue
    for index in arm_groups:
        panel.vertex_groups[index].remove([vertex.index])
    torso.add([vertex.index], weight, 'ADD')
    changed += 1
panel['pallu_torso_support_version'] = 1
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('PALLU_SUPPORT', args.identity, 'vertices', changed, 'REEXPORT_AND_AUDIT_REQUIRED', flush=True)
