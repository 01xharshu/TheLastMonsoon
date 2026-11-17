"""Apply fuller adult MPFB proportions to an isolated editable study.

The complete body remains the shared source of shape for all garments. The
nearest-surface transfer is an initial fit only; it is not art approval.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body

parser = argparse.ArgumentParser()
parser.add_argument('--identity', required=True)
parser.add_argument('--source', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
if args.identity not in {f'female_{n:02}' for n in range(1, 7)}:
    raise ValueError('Select one of the six adult female profiles')
source, output = args.source.expanduser().resolve(), args.output.expanduser().resolve()
if not source.is_file() or source == output or output.exists():
    raise ValueError('Select an existing study and a separate new output file')
profile_dir = ROOT / 'WorkingAssets/NPCs/indian_body_profiles'
manifest = json.loads((profile_dir / 'female_fuller_manifest.json').read_text())
if float(manifest['adult_age']) < .35:
    raise ValueError('The source profile must be clearly adult')
original = np.load(profile_dir / 'female_mpfb_deltas.npz')[args.identity]
fuller = np.load(profile_dir / 'female_fuller_mpfb_deltas.npz')[args.identity]
delta = (fuller - original).copy()
candidate_dir = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / args.identity
candidate = json.loads((candidate_dir / 'manifest.json').read_text())
donor_manifest = ROOT / Path(candidate['source']).parent / 'manifest.json'
width = float(json.loads(donor_manifest.read_text())['whole_character_width'])
delta[:, 0] *= width
if not np.isfinite(delta).all() or float(np.linalg.norm(delta, axis=1).max()) > .06:
    raise RuntimeError('Unexpected profile displacement')

bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
if body.get('body_profile') != args.identity or len(body.data.vertices) != len(delta):
    raise RuntimeError('Study does not match its requested complete MPFB body')
if body.data.shape_keys and body.data.shape_keys.key_blocks.get('Adult MPFB increased proportions'):
    raise RuntimeError('Study already has the increased-proportions key')
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.data.pose_position = 'REST'
modifiers = [(m, m.show_viewport) for m in body.modifiers]
for modifier, _ in modifiers:
    if modifier.type in ('ARMATURE', 'MASK'):
        modifier.show_viewport = False
bpy.context.view_layer.update()
evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = evaluated.to_mesh()
group = body.vertex_groups['body'].index
human = [v.index for v in body.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)]
tree = KDTree(len(human))
def smooth(a, b, value):
    t = max(0.0, min(1.0, (value - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)

strength = np.zeros(len(delta), dtype=np.float32)
for index in human:
    p = body.matrix_world @ mesh.vertices[index].co
    tree.insert(p, index)
    # Reapplying MPFB macros can otherwise introduce unrelated differences
    # (including facial changes). Restrict this requested change to the
    # existing adult torso and seat, with soft transitions into nearby skin.
    chest = (smooth(.96, 1.02, p.z) * (1.0 - smooth(1.20, 1.27, p.z))
             * smooth(0.0, .04, -p.y) * (1.0 - smooth(.14, .21, abs(p.x))))
    seat = (smooth(.61, .69, p.z) * (1.0 - smooth(.86, .94, p.z))
            * smooth(.005, .055, p.y) * (1.0 - smooth(.13, .21, abs(p.x))))
    strength[index] = max(chest, seat)
tree.balance()
evaluated.to_mesh_clear()
delta *= strength[:, None]
if float(np.linalg.norm(delta, axis=1).max()) < .001:
    raise RuntimeError('Profile adjustment did not reach the adult torso or seat')

key = body.shape_key_add(name='Adult MPFB increased proportions', from_mix=False)
base = body.data.shape_keys.reference_key.data
for index, vertex in enumerate(key.data):
    # Blender can initialize a new key from the current mesh rather than the
    # reference key. Explicitly use Basis so existing facial/body keys are not
    # accidentally applied a second time.
    vertex.co = base[index].co + Vector(delta[index])
key.value = 1.0
names = ['Opaque fitted bra and thong foundation', 'Street coherent cotton blouse and pallu',
         'Street sari front pallu', 'Street sari back tail', 'Wrapped sari lower drape', 'Sari lower border']
adjusted = {}
for name in names:
    garment = bpy.data.objects.get(name)
    if garment is None or garment.get('street_source_only', False):
        continue
    inverse = garment.matrix_world.inverted()
    linear = inverse.to_3x3() @ body.matrix_world.to_3x3()
    blocks = [garment.data.vertices]
    if garment.data.shape_keys:
        blocks += [block.data for block in garment.data.shape_keys.key_blocks]
    for vertices in blocks:
        for vertex in vertices:
            _, index, distance = tree.find(garment.matrix_world @ vertex.co)
            if distance <= .15:
                vertex.co += linear @ Vector(delta[index])
    garment.data.update()
    adjusted[name] = len(garment.data.vertices)
for modifier, enabled in modifiers:
    modifier.show_viewport = enabled
retain_complete_body(body)
body['fuller_profile'] = args.identity
body['approval'] = 'Unapproved study; clothing, motion and live integration require review'
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('FULLER_BODY_STUDY', args.identity, 'max_delta_mm', float(np.linalg.norm(delta, axis=1).max()) * 1000,
      'complete_body_vertices', len(body.data.vertices), 'garments', adjusted, 'unapproved', str(output), flush=True)
