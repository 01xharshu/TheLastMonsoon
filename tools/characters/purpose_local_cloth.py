"""Bounded local cloth clearance keys over unchanged complete posed bodies.

Preserves topology and skin weights. Samples vertices and polygon centres;
this only addresses idle/walk contact, not continuous collision or final art approval.
"""
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def _fit_pose(rig, obj, tree, key, vertex_priority=False):
    clearance = .010 if rig.name.startswith('boatman_') else .005
    transforms=[]
    for v in obj.data.vertices:
     blend=Matrix.Identity(4)*0;total=0
     for g in v.groups:
      bone=rig.pose.bones.get(obj.vertex_groups[g.group].name)
      if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*g.weight;total+=g.weight
     transforms.append((rig.matrix_world @ (blend*(1/total) if total else Matrix.Identity(4)) @ rig.matrix_world.inverted() @ obj.matrix_world).to_3x3())
    for iteration in range(20 if rig.name.startswith('record_clerk_') else 12):
     bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
     shifts=[Vector() for _ in obj.data.vertices];counts=[0]*len(shifts)
     for polygon in mesh.polygons:
      point=ev.matrix_world@polygon.center;near,normal,_,dist=tree.find_nearest(point)
      depth=(near-point).dot(normal)
      if dist<.10 and depth > -(clearance - .001):
       shift=normal*min(depth+clearance,.012)
       for i in polygon.vertices:shifts[i]+=shift;counts[i]+=1
     for v in mesh.vertices:
      point=ev.matrix_world@v.co;near,normal,_,dist=tree.find_nearest(point);depth=(near-point).dot(normal)
      if dist<.10 and depth > -(clearance - .001):
       if vertex_priority:shifts[v.index]=normal*min(depth+clearance,.012);counts[v.index]=1
       else:shifts[v.index]+=normal*min(depth+clearance,.012);counts[v.index]+=1
     ev.to_mesh_clear()
     for i,shift in enumerate(shifts):
      if counts[i]:key.data[i].co+=transforms[i].inverted_safe()@(shift/counts[i])

def fit_local_walk_cloth(rig, body):
    if not body.name.startswith(('boatman_', 'dock_porter_', 'record_clerk_')):
        return
    rig.animation_data.action = bpy.data.actions['walk']
    rig.data.pose_position = 'POSE'
    names=['Fitted cotton upper base','Porter fitted short work trousers','Clerk full length trousers','Clerk buttoned sleeveless waistcoat']
    objects=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
    for obj in objects:
     if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
    samples = 24 if body.name.startswith('boatman_') else 72
    for sample in range(samples):
     frame=1+sample*36/samples;bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
     dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
     tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
     for obj in objects:
      key=obj.shape_key_add(name='Walk cloth %02d'%sample);key.value=1
      _fit_pose(rig, obj, tree, key)
      key.value=0
     print('LOCAL_CLOTH_SAMPLE',sample,flush=True)
    # The resting garment must also clear the complete body. Change Basis,
    # retaining each walk key's absolute fitted coordinates for transitions.
    rig.animation_data.action = bpy.data.actions['idle']
    bpy.context.scene.frame_set(31)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    mesh = ev.to_mesh()
    tree = BVHTree.FromPolygons([ev.matrix_world @ v.co for v in mesh.vertices],
                               [tuple(p.vertices) for p in mesh.polygons])
    ev.to_mesh_clear()
    for obj in objects:
        basis = obj.data.shape_keys.key_blocks['Basis']
        _fit_pose(rig, obj, tree, basis)
        for vertex in obj.data.vertices:
            vertex.co = basis.data[vertex.index].co
