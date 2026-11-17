"""Trim a disposable sleeveless artisan pattern while retaining weights and keys."""
import sys
import tempfile
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
source_path = ROOT / 'WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_workwear.blend'
output = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
if not output.is_relative_to(Path(tempfile.gettempdir()).resolve()) or output.exists():
    raise ValueError('Output must be a new file under the OS temporary directory')

bpy.ops.wm.open_mainfile(filepath=str(source_path))
source = bpy.data.objects['Workwear transfer study']
original_keys = source.data.shape_keys.key_blocks
basis = original_keys[0].data
upper_count = int(source['occupation_upper_vertex_count'])
vertices = []
vertex_map = {}
triangles = []


def distance(index, side):
    point = source.matrix_world @ basis[index].co
    width = .150 + max(0.0, 1.18 - point.z) * .42
    return width - side * point.x


def corner(left, right=None, fraction=0):
    if right is None:
        right = left
    if left > right:
        left, right = right, left
        fraction = 1 - fraction
    identifier = (left, right, round(fraction, 8))
    if identifier not in vertex_map:
        vertex_map[identifier] = len(vertices)
        vertices.append((left, right, fraction))
    return vertex_map[identifier]


def emit(indices):
    for i in range(1, len(indices) - 1):
        triangle = (indices[0], indices[i], indices[i + 1])
        if len(set(triangle)) == 3:
            triangles.append(triangle)


source.data.calc_loop_triangles()
for triangle in source.data.loop_triangles:
    face = tuple(triangle.vertices)
    if any(index >= upper_count for index in face):
        continue
    # A triangle cannot reach both opposed armhole boundaries. Clip against
    # its own side and preserve each shared cut edge as a single vertex.
    side = 1 if sum((source.matrix_world @ basis[i].co).x for i in face) >= 0 else -1
    polygon = []
    for left, right in zip(face, face[1:] + face[:1]):
        dl, dr = distance(left, side), distance(right, side)
        if dl >= 0:
            polygon.append(corner(left))
        if (dl >= 0) != (dr >= 0):
            polygon.append(corner(left, right, dl / (dl - dr)))
    emit(polygon)

new_upper_count = len(vertices)
for triangle in source.data.loop_triangles:
    face = tuple(triangle.vertices)
    if all(index >= upper_count for index in face):
        emit([corner(index) for index in face])

mesh = bpy.data.meshes.new('Sleeveless workwear trial')
mesh.from_pydata([basis[a].co.lerp(basis[b].co, t) for a, b, t in vertices], [], triangles)
mesh.update()
replacement = bpy.data.objects.new('Sleeveless workwear trial', mesh)
bpy.context.collection.objects.link(replacement)
replacement.parent = source.parent
replacement.matrix_world = source.matrix_world.copy()
replacement['occupation_upper_vertex_count'] = new_upper_count
for group in source.vertex_groups:
    replacement.vertex_groups.new(name=group.name)
for index, (a, b, fraction) in enumerate(vertices):
    weights = {}
    for vertex, factor in ((a, 1 - fraction), (b, fraction)):
        for group in source.data.vertices[vertex].groups:
            weights[group.group] = weights.get(group.group, 0) + group.weight * factor
    for group, weight in weights.items():
        if weight > 0:
            replacement.vertex_groups[group].add([index], weight, 'REPLACE')
for original in original_keys:
    key = replacement.shape_key_add(name=original.name)
    for point, (a, b, fraction) in zip(key.data, vertices):
        point.co = original.data[a].co.lerp(original.data[b].co, fraction)
armature = replacement.modifiers.new('Original occupation armature', 'ARMATURE')
armature.object = source.find_armature()
bpy.data.objects.remove(source, do_unlink=True)
replacement.name = 'Workwear transfer study'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('OCCUPATION_VEST_TRIAL', new_upper_count, len(vertices), len(triangles), flush=True)
