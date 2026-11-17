"""Compare torso/thigh contacts in native seat poses on the original body."""
import json
import sys
from pathlib import Path

import bpy
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from occupation_layered_fit import surface
from occupation_native_pose import apply
from river_triangle_contact import crosses

source, *samples = [Path(arg).resolve() for arg in sys.argv[sys.argv.index('--') + 1:]]
bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects['artisan_complete_MakeHuman_body']
rig = body.find_armature()
body.data.calc_loop_triangles()
groups = [group.name for group in body.vertex_groups]
hip = rig.matrix_world @ rig.data.bones['pelvis'].head_local
part = []
for vertex in body.data.vertices:
    weights = {groups[item.group]: item.weight for item in vertex.groups}
    position = body.matrix_world @ vertex.co
    if position.z > hip.z + .025 and sum(weights.get(bone, 0) for bone in
                                         ('pelvis', 'spine_01', 'spine_02', 'spine_03')) > .6:
        part.append('torso')
    elif weights.get('thigh_l', 0) > .55:
        part.append('left')
    elif weights.get('thigh_r', 0) > .55:
        part.append('right')
    else:
        part.append('other')
faces = {region: [tuple(triangle.vertices) for triangle in body.data.loop_triangles
                  if all(part[index] == region for index in triangle.vertices)]
         for region in ('torso', 'left', 'right')}
assert all(faces.values()), 'Body region classification is empty'

for sample in samples:
    apply(rig, json.loads(sample.read_text()))
    _, points = surface(body)
    trees = {region: BVHTree.FromPolygons(points, triangles, all_triangles=True)
             for region, triangles in faces.items()}
    contacts = {}
    for first, second in (('torso', 'left'), ('torso', 'right'), ('left', 'right')):
        contacts[first + '/' + second] = sum(
            crosses([points[i] for i in faces[first][a]], [points[i] for i in faces[second][b]])
            for a, b in trees[first].overlap(trees[second]))
    print('OCCUPATION_SEAT_BODY', sample.parent.name, json.dumps(contacts), flush=True)
