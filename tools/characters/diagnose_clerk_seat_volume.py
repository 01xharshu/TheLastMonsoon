"""Read-only full-skin topology and exterior-volume sanity checks."""
import bpy,sys,collections
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
from purpose_cloth_volume import inside_surface
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'))
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body'];rig.animation_data.action=bpy.data.actions['seat_entry']
faces=native_triangles(rig,[body],ROOT/'characters/npcs/review/record_clerk_seat.glb')[body.name]
edges=collections.Counter(tuple(sorted((face[i],face[(i+1)%3]))) for face in faces for i in range(3))
print('BODY_SKIN_EDGES','boundary',sum(n==1 for n in edges.values()),'nonmanifold',sum(n>2 for n in edges.values()),flush=True)
for frame in [1,27,61]:
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 points=[ev.matrix_world@v.co for v in mesh.vertices];tree=BVHTree.FromPolygons(points,faces,all_triangles=True);ev.to_mesh_clear()
 center=(Vector(tuple(min(p[i] for p in points) for i in range(3)))+Vector(tuple(max(p[i] for p in points) for i in range(3))))*.5
 outside=[center+Vector(axis)*1.2 for axis in [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]]
 print('BODY_EXTERIOR_SANITY',frame,[inside_surface(tree,p) for p in outside],flush=True)
