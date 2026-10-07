"""Bounded local cloth clearance keys over unchanged complete posed bodies.

Preserves topology and skin weights. Samples vertices and polygon centres;
this only addresses idle/walk contact, not continuous collision or final art approval.
"""
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def _fit_pose(rig, obj, tree, key):
    clearance = .012
    transforms=[]
    for v in obj.data.vertices:
     blend=Matrix.Identity(4)*0;total=0
     for g in v.groups:
      bone=rig.pose.bones.get(obj.vertex_groups[g.group].name)
      if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*g.weight;total+=g.weight
     transforms.append((rig.matrix_world @ (blend*(1/total) if total else Matrix.Identity(4)) @ rig.matrix_world.inverted() @ obj.matrix_world).to_3x3())
    for iteration in range(64):
     bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
     shifts=[Vector() for _ in obj.data.vertices];counts=[0]*len(shifts)
     for polygon in mesh.polygons:
      point=ev.matrix_world@polygon.center;near,normal,_,dist=tree.find_nearest(point)
      depth=(near-point).dot(normal)
      if dist<.10 and depth > -(clearance - .001):
       shift=normal*min(depth+clearance,.006)
       for i in polygon.vertices:shifts[i]+=shift;counts[i]+=1
     for v in mesh.vertices:
      point=ev.matrix_world@v.co;near,normal,_,dist=tree.find_nearest(point);depth=(near-point).dot(normal)
      if dist<.10 and depth > -(clearance - .001):shifts[v.index]+=normal*min(depth+clearance,.006);counts[v.index]+=1
     ev.to_mesh_clear()
     if not any(counts):break
     for i,shift in enumerate(shifts):
      if counts[i]:key.data[i].co+=transforms[i].inverted_safe()@(shift/counts[i])

