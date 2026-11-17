"""Reject native occupation samples with body or interlayer intersections.

Consume only OS temporary Godot posed-surface JSON; emit concise diagnostics.
Run with Blender's Python for the same independent BVH/volume implementation.
"""
import json
from pathlib import Path
import sys
import tempfile
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
from purpose_cloth_volume import VolumeSurface, inside_surface
from river_triangle_contact import crosses
folder=Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert folder.is_relative_to(Path(tempfile.gettempdir()).resolve())
failed=False
sampled=0
options=sys.argv[sys.argv.index('--')+2:]
steady_only='--steady-only' in options
workplace='--workplace' in options
workplace_cycle='--workplace-cycle' in options
all_samples=workplace or '--all-samples' in options
for path in sorted(folder.glob('*.json')):
    if not all_samples and not path.stem.endswith(('_16',) if steady_only else ('_03','_08','_16')):continue
    sampled+=1
    data=json.loads(path.read_text())
    meshes={}
    for entry in data['meshes']:
        name=entry['name']
        points=[Vector(p) for p in entry['vertices']]
        ids=entry['indices'];faces=[tuple(ids[i:i+3]) for i in range(0,len(ids),3)]
        meshes[name]=(points,faces)
    body=next(value for name,value in meshes.items() if 'complete_MakeHuman_body' in name)
    volume=VolumeSurface.FromPolygons(*body,strict=True)
    body_points, body_faces = body
    body_tree = BVHTree.FromPolygons(body_points, body_faces, all_triangles=True)
    outer={name:value for name,value in meshes.items() if 'cotton' in name or 'foundation' in name}
    contacts={}
    for name,(points,faces) in outer.items():
        probes=points+[sum((points[i] for i in f),Vector())/3 for f in faces]
        count=0;worst=0
        for p in probes:
            nearest=volume.find_nearest(p)
            if nearest and nearest[3]>.001 and inside_surface(volume,p):
                count+=1;worst=max(worst,nearest[3])
        tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
        self_count=0
        for left,right in tree.overlap(tree):
            if left>=right or set(faces[left]).intersection(faces[right]):continue
            if crosses([points[i] for i in faces[left]],[points[i] for i in faces[right]]):self_count+=1
        body_crossings = 0
        crossing_heights = set()
        for cloth_face, body_face in tree.overlap(body_tree):
            cloth_triangle = [points[i] for i in faces[cloth_face]]
            skin_triangle = [body_points[i] for i in body_faces[body_face]]
            if crosses(cloth_triangle, skin_triangle):
                body_crossings += 1
                crossing_heights.add(round(sum(point.y for point in cloth_triangle) / .15) * 5)
        contacts[name]={'body':count,'worst_mm':round(worst*1000,3),'self':self_count,
                        'body_crossings':body_crossings,'crossing_height_cm':sorted(crossing_heights)}
        failed |= count > 0 or self_count > 0 or body_crossings > 0
    pairs={};names=list(outer)
    for ai,name in enumerate(names):
        points,faces=outer[name];a=BVHTree.FromPolygons(points,faces,all_triangles=True)
        for other in names[ai+1:]:
            op,of=outer[other];b=BVHTree.FromPolygons(op,of,all_triangles=True)
            count=sum(crosses([points[i] for i in faces[x]],[op[i] for i in of[y]]) for x,y in a.overlap(b))
            pairs[name+' / '+other]=count;failed|=count>0
    foundation=next(value for name,value in outer.items() if 'foundation' in name)
    outer_points=[];outer_faces=[]
    for name,(points,faces) in outer.items():
        if 'foundation' in name:continue
        offset=len(outer_points);outer_points.extend(points)
        outer_faces.extend(tuple(i+offset for i in face) for face in faces)
    cover=BVHTree.FromPolygons(outer_points,outer_faces,all_triangles=True)
    directions=[Vector((x,y,z)).normalized() for x in (-1,0,1) for y in (-1,0,1)
                for z in (-1,0,1) if x or y or z]
    def visible(point,clothes):
        for direction in directions:
            origin=point+direction*.0001
            if volume.ray_cast(origin,direction,4.0)[0] is not None:continue
            if clothes and cover.ray_cast(origin,direction,4.0)[0] is not None:continue
            return True
        return False
    ip,faces=foundation
    probes=ip+[sum((ip[i] for i in face),Vector())/3 for face in faces]
    exposed=sum(visible(point,True) for point in probes)
    control=sum(visible(point,False) for point in probes)
    assert control>0,'Foundation visibility negative control must expose samples'
    failed|=exposed>0
    sample_failed=exposed or any(pairs.values()) or any(c['body'] or c['self'] or c['body_crossings'] for c in contacts.values())
    if all_samples and not sample_failed:continue
    print('OCCUPATION_NATIVE_CONTACT',data['pose'],data['sample'],json.dumps(contacts),json.dumps(pairs),
          'foundation_visible',exposed,'negative_control',control,flush=True)
assert sampled == (39 if workplace_cycle else 21 if workplace else 119 if all_samples else 7 if steady_only else 21), f'Unexpected sample count: {sampled}'
print('OCCUPATION_NATIVE_CONTACT_RESULT', 'FAIL' if failed else 'PASS', 'samples', sampled, flush=True)
if failed:raise RuntimeError('Native garment contact failed; candidate must not replace production')
