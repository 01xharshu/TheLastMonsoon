"""Create a mirrored lower-clothing gait corrective in a temporary candidate."""
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

source, output = (Path(arg).resolve() for arg in sys.argv[sys.argv.index('--') + 1:])
root = Path(__file__).resolve().parents[2]
if not source.is_relative_to(root / 'WorkingAssets/NPCs/occupation_wardrobe'):
    raise ValueError('Expected a retained editable occupation candidate')
if not output.is_relative_to(Path(tempfile.gettempdir()).resolve()) or output.exists():
    raise ValueError('Expected a new temporary output')
bpy.ops.wm.open_mainfile(filepath=str(source))
outer = bpy.data.objects['Workwear transfer study']
inner = bpy.data.objects['Street opaque foundation']


def mirrored(vector):
    return Vector((-vector.x, vector.y, vector.z))


for obj, start, key_suffix in ((outer, int(outer['occupation_upper_vertex_count']), 'correction'),
                               (inner, 0, 'foundation')):
    basis = obj.data.shape_keys.reference_key
    forward = obj.data.shape_keys.key_blocks['Study walk ' + key_suffix]
    reverse = obj.shape_key_add(name='Study reverse walk ' + key_suffix)
    lookup = KDTree(len(basis.data) - start)
    for index in range(start, len(basis.data)):
        lookup.insert(basis.data[index].co, index)
    lookup.balance()
    for index in range(start, len(basis.data)):
        rest = basis.data[index].co
        neighbors = lookup.find_n(mirrored(rest), 4)
        displacement = Vector()
        total = 0.0
        for _, match, distance in neighbors:
            weight = 1.0 / (distance * distance + .000004)
            displacement += mirrored(forward.data[match].co - basis.data[match].co) * weight
            total += weight
        reverse.data[index].co = rest + displacement / total
    reverse.value = 0
    print('OCCUPATION_REVERSE_WALK_KEY', obj.name, len(basis.data) - start, flush=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output))
