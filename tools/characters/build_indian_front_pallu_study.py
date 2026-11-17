"""Build a separate front sari panel over an editable, unapproved study.

This is an experimental fabric layer, not a production export. The required
output must be new, so the source study and retained human remain recoverable.
"""
import argparse
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--right-width', type=float, default=.095,
                    help='Width in metres on the inner edge of the draped strip')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
if not .025 <= args.right_width <= .12:
    raise ValueError('Front pallu width must be between 25 and 120 mm')
source, output = args.source.expanduser().resolve(), args.output.expanduser().resolve()
if not source.is_file() or source == output or output.exists():
    raise ValueError('Select an existing study and a separate new output file')
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.preferences.filepaths.save_version = 0
blouse = bpy.data.objects['Street coherent cotton blouse and pallu']
if bpy.data.objects.get('Street sari front pallu') is not None:
    raise ValueError('Study already contains a front pallu')
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
tail = bpy.data.objects['Street sari back tail']
body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
blouse.data.calc_loop_triangles()
normals = [Vector() for v in blouse.data.vertices]
for tri in blouse.data.loop_triangles:
    ids = tuple(tri.vertices)
    a, b, c = [blouse.data.vertices[i].co for i in ids]
    normal = (b - a).cross(c - a)
    for i in ids:
        normals[i] += normal

def interpolate(a, b, t):
    groups = set(a['weights']) | set(b['weights'])
    return {'co': a['co'].lerp(b['co'], t), 'normal': a['normal'].lerp(b['normal'], t),
            'weights': {g: a['weights'].get(g, 0.0) * (1.0 - t) + b['weights'].get(g, 0.0) * t
                        for g in groups}}

def clip(poly, distance):
    if not poly:
        return []
    out = []
    previous = poly[-1]
    before = distance(blouse.matrix_world @ previous['co'])
    for current in poly:
        after = distance(blouse.matrix_world @ current['co'])
        if (before >= 0) != (after >= 0):
            out.append(interpolate(previous, current, before / (before - after)))
        if after >= 0:
            out.append(current)
        previous, before = current, after
    return out

def centre(p):
    return .14 - (p.z - .85) * .29 / .39

constraints = [lambda p: p.z - .98, lambda p: 1.295 - p.z, lambda p: .03 - p.y,
               lambda p: args.right_width - (p.x - centre(p)), lambda p: .095 + (p.x - centre(p))]
vertices, faces, by_position = [], [], {}
for tri in blouse.data.loop_triangles:
    poly = [{'co': blouse.data.vertices[i].co.copy(), 'normal': normals[i].copy(),
             'weights': {g.group: g.weight for g in blouse.data.vertices[i].groups}}
            for i in tri.vertices]
    for constraint in constraints:
        poly = clip(poly, constraint)
    if len(poly) < 3:
        continue
    indices = []
    for point in poly:
        stamp = tuple(round(v, 6) for v in point['co'])
        if stamp not in by_position:
            by_position[stamp] = len(vertices)
            vertices.append(point)
        indices.append(by_position[stamp])
    for i in range(1, len(indices) - 1):
        face = (indices[0], indices[i], indices[i + 1])
        if len(set(face)) == 3:
            faces.append(face)
if len(vertices) < 30 or not faces:
    raise RuntimeError('Insufficient front pallu coverage')
mesh = bpy.data.meshes.new('Separate front sari cotton')
mesh.from_pydata([p['co'] + p['normal'].normalized() * .012 for p in vertices], [], faces)
mesh.update()
panel = bpy.data.objects.new('Street sari front pallu', mesh)
bpy.context.collection.objects.link(panel)
panel.parent = blouse.parent
panel.matrix_parent_inverse = blouse.matrix_parent_inverse.copy()
panel.matrix_basis = blouse.matrix_basis.copy()
for group in blouse.vertex_groups:
    panel.vertex_groups.new(name=group.name)
for j, point in enumerate(vertices):
    for group, weight in point['weights'].items():
        if weight > .000001:
            panel.vertex_groups[group].add([j], weight, 'REPLACE')
panel.modifiers.new('Original MPFB rig', 'ARMATURE').object = rig
mesh.materials.append(tail.data.materials[0])
panel['construction'] = 'Experimental separate front sari panel fitted over blouse'
for face in mesh.polygons:
    face.use_smooth = True
color = blouse.data.color_attributes.get('StreetCotton')
if color is None or color.domain != 'POINT' or not color.data:
    raise RuntimeError('Missing blouse point colors')
palette = Counter(tuple(round(c, 4) for c in item.color) for item in color.data)
blouse_color = palette.most_common(1)[0][0]
for item in color.data:
    item.color = blouse_color
retain_complete_body(body)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('FRONT_PALLU_STUDY', len(vertices), len(faces), 'unapproved', str(output), flush=True)
