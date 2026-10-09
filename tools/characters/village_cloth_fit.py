"""Bounded local cloth clearance keys over unchanged complete posed bodies.

Preserves topology and skin weights. Samples vertices and polygon centres;
this only addresses idle/walk contact, not continuous collision or final art approval.
"""
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def sample_faces(mesh):
    mesh.calc_loop_triangles()
    faces=[tuple(t.vertices) for t in mesh.loop_triangles]
    # glTF/Godot can choose the opposite quad diagonal after normal/UV splits.
    # Constrain both triangulations of the same editable cloth surface.
    for polygon in mesh.polygons:
        if len(polygon.vertices)==4:
            a,b,c,d=polygon.vertices
            faces.extend([(a,b,d),(b,c,d),(a,b,c),(a,c,d)])
    return list(dict.fromkeys(faces))

def _fit_pose(rig, obj, tree, key):
    targets=key if isinstance(key,(list,tuple)) else [key]
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
     for face in sample_faces(mesh):
      point=ev.matrix_world@(sum((mesh.vertices[i].co for i in face),Vector())/len(face));near,normal,_,dist=tree.find_nearest(point)
      depth=(near-point).dot(normal)
      if dist<.10 and depth > -(clearance - .001):
       shift=normal*min(depth+clearance,.006)
       for i in face:shifts[i]+=shift;counts[i]+=1
     for v in mesh.vertices:
      point=ev.matrix_world@v.co;near,normal,_,dist=tree.find_nearest(point);depth=(near-point).dot(normal)
      # Give a direct penetrating vertex priority over neighbouring face pushes.
      if dist<.10 and depth > -(clearance - .001):
       shifts[v.index]=normal*min(depth+clearance,.012);counts[v.index]=1
     ev.to_mesh_clear()
     if not any(counts):break
     for i,shift in enumerate(shifts):
      if counts[i]:
       correction=transforms[i].inverted_safe()@(shift/counts[i])
       for target in targets:target.data[i].co+=correction

