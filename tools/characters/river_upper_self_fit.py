"""Remove cloth-only folded triangles while preserving the complete MPFB body."""
import bpy
from collections import Counter,defaultdict
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from river_surface_binding import inverse_skin
from river_triangle_contact import crosses
from river_coherent_cloth import fit_key

def points_of(obj):
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    points=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear();return points

def self_hits(points,faces):
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True);hits=0
    for a,b in tree.overlap(tree):
        if a>=b or set(faces[a]).intersection(faces[b]):continue
        if crosses([points[i] for i in faces[a]],[points[i] for i in faces[b]]):hits+=1
    return hits

def stitch_construction_seams(obj,key,points,inverse):
    # The donor has coincident split vertices at sewn edges. Fit each copy to
    # the same world point; independent projection otherwise opens tiny folds.
    basis=obj.data.shape_keys.reference_key.data
    tree=KDTree(len(basis))
    for i,v in enumerate(basis):tree.insert(v.co,i)
    tree.balance();seen=set()
    for i,v in enumerate(basis):
        if i in seen:continue
        group=[j for _,j,_ in tree.find_range(v.co,.000002)]
        seen.update(group)
        if len(group)<2:continue
        mean=sum((points[j] for j in group),Vector())/len(group)
        if max((points[j]-mean).length for j in group)>.015:
            raise RuntimeError('Sewn cotton edge split exceeds15mm: '+key.name)
        for j in group:
            points[j]=mean.copy();key.data[j].co=inverse[j]@mean
    return points

def regularize_upper(rig,obj,tree,key):
    obj.data.calc_loop_triangles();faces=[tuple(t.vertices) for t in obj.data.loop_triangles]
    inverse=inverse_skin(rig,obj)
    points=stitch_construction_seams(obj,key,points_of(obj),inverse)
    if not self_hits(points,faces):return 0
    edges=Counter();neighbors=defaultdict(set)
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            edges[tuple(sorted((a,b)))]+=1;neighbors[a].add(b);neighbors[b].add(a)
    boundary={i for edge,count in edges.items() if count==1 for i in edge}
    original=[point.copy() for point in points];inverse=inverse_skin(rig,obj)
    for iteration in range(4):
        for sweep in range(3):
            previous=[p.copy() for p in points]
            for index,adjacent in neighbors.items():
                if index in boundary:continue
                mean=sum((previous[i] for i in adjacent),Vector())/len(adjacent)
                target=previous[index]*.6+mean*.4
                change=target-original[index]
                if change.length>.015:target=original[index]+change.normalized()*.015
                points[index]=target
        for index,point in enumerate(points):key.data[index].co=inverse[index]@point
        fit_key(rig,obj,tree,key,reset_key=False,minimum_clearance_m=.008,jacobi=True)
        points=stitch_construction_seams(obj,key,points_of(obj),inverse)
        if not self_hits(points,faces):return iteration+1
    raise RuntimeError('Cotton self-intersection remains: '+key.name)
