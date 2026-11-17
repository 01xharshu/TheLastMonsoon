"""Bring unsupported upper fabric edges onto their actual layered support.

Edits only separate garments in a new study, preserving the full adult body.
The local seam adjustment is bounded; body/layer/motion and native review are
still required before accepting the study.
"""
import argparse
from collections import Counter
import heapq
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);source=args.source.resolve();output=args.output.resolve()
if not source.is_file() or output.exists() or source==output:raise ValueError('Requires a separate new study output')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
mask_states=[(m,m.show_viewport) for m in body.modifiers if m.type=='MASK']
for modifier,_ in mask_states:modifier.show_viewport=False
bpy.context.view_layer.update()

def surface(obj,human_only=False):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
    points=[obj.matrix_world@v.co for v in mesh.vertices]
    human=None
    if human_only:
        group=obj.vertex_groups['body'].index
        human={v.index for v in obj.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)}
    faces=[tuple(t.vertices) for t in mesh.loop_triangles if human is None or all(i in human for i in t.vertices)]
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
    evaluated.to_mesh_clear();return tree

skin=surface(body,True)
foundation=surface(bpy.data.objects['Opaque fitted bra and thong foundation'])
for name in ['Street coherent cotton blouse and pallu','Street sari front pallu']:
    obj=bpy.data.objects[name]
    basis=obj.data.shape_keys.reference_key.data if obj.data.shape_keys else obj.data.vertices
    original=[v.co.copy() for v in basis];world=[obj.matrix_world@point for point in original]
    counts=Counter(tuple(sorted(edge)) for polygon in obj.data.polygons for edge in polygon.edge_keys)
    boundary={index for edge,count in counts.items() if count==1 for index in edge}
    seeds={i for i in boundary if world[i].z>1.18 and abs(world[i].x)<.18}
    if not seeds:raise RuntimeError('No supported shoulder/neck seam found: '+name)
    neighbors=[[] for _ in original]
    for edge in obj.data.edges:
        a,b=edge.vertices;length=(world[a]-world[b]).length
        neighbors[a].append((b,length));neighbors[b].append((a,length))
    distances={i:0. for i in seeds};queue=[(0.,i) for i in seeds];heapq.heapify(queue)
    while queue:
        distance,index=heapq.heappop(queue)
        if distance!=distances[index]:continue
        for other,length in neighbors[index]:
            value=distance+length
            if value<.04 and value<distances.get(other,1.):distances[other]=value;heapq.heappush(queue,(value,other))
    supports=[foundation]
    if name=='Street sari front pallu':supports.append(surface(bpy.data.objects['Street coherent cotton blouse and pallu']))
    blocks=[obj.data.vertices]
    if obj.data.shape_keys:blocks += [key.data for key in obj.data.shape_keys.key_blocks]
    inverse=obj.matrix_world.inverted();maximum=0.;changed=0
    for index,distance in distances.items():
        point=world[index];near,normal,_,gap=skin.find_nearest(point)
        if near is None or gap>.06:continue
        # Do not use a garment behind the local skin surface as support.
        target=near+normal*.004
        for support in supports:
            cursor=near-normal*.0005
            for _ in range(8):
                hit,_,_,_=support.ray_cast(cursor,normal,.04)
                if hit is None:break
                if (hit-target).dot(normal)>0:target=hit+normal*.004
                cursor=hit+normal*.0001
        t=max(0.,min(1.,distance/.04));strength=1-t*t*(3-2*t)
        shift=(target-point)*strength
        if shift.length>.04:raise RuntimeError('Seam fit exceeds40mm; no study saved')
        if shift.length<.00001:continue
        local=inverse@(point+shift)-original[index]
        for block in blocks:block[index].co+=local
        maximum=max(maximum,shift.length);changed+=1
    obj.data.update();bpy.context.view_layer.update()
    print('NECKLINE_SEAM_FIT',name,'seeds',len(seeds),'changed',changed,'max_mm',maximum*1000,flush=True)
for modifier,enabled in mask_states:modifier.show_viewport=enabled
output.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('NECKLINE_STUDY_UNAPPROVED',output,flush=True)
