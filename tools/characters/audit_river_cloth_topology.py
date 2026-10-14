"""Inspect editable runtime cloth openings; emit text only, no retained report."""
import bpy
from pathlib import Path
from collections import Counter,defaultdict
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
obj=bpy.data.objects['Fitted cotton upper base'];obj.data.calc_loop_triangles()
counts=Counter()
for triangle in obj.data.loop_triangles:
    for i in range(3):counts[tuple(sorted((triangle.vertices[i],triangle.vertices[(i+1)%3])))]+=1
graph=defaultdict(set)
for (a,b),count in counts.items():
    if count==1:graph[a].add(b);graph[b].add(a)
pending=set(graph);loops=[];points=obj.data.shape_keys.key_blocks['Basis'].data
while pending:
    seed=min(pending);component={seed};stack=[seed];pending.remove(seed)
    while stack:
        for adjacent in graph[stack.pop()]:
            if adjacent not in component:component.add(adjacent);pending.discard(adjacent);stack.append(adjacent)
    bounds=[[min(points[i].co[axis] for i in component),max(points[i].co[axis] for i in component)] for axis in range(3)]
    loops.append({'vertices':len(component),'bounds':bounds,'closed':all(len(graph[i])==2 for i in component)})
rig=next(modifier.object for modifier in obj.modifiers if modifier.type=='ARMATURE')
bad_weights=sum(abs(sum(group.weight for group in vertex.groups if obj.vertex_groups[group.group].name in rig.data.bones)-1.0)>.005 for vertex in obj.data.vertices)
print('RIVER_CLOTH_TOPOLOGY',{'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),'nonmanifold_edges':sum(count>2 for count in counts.values()),'branched_boundary_vertices':sum(len(neighbors)!=2 for neighbors in graph.values()),'bad_skin_weight_vertices':bad_weights,'openings':loops},flush=True)
if bad_weights:raise RuntimeError('Runtime garment skin weights failed')
