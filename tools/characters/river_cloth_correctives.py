"""Fit river garments to sampled runtime poses of the unchanged MPFB body."""
import bpy, json
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from purpose_local_cloth import _fit_pose

def wrap_lower(rig,obj,key,leg_points,floor):
    """Keep a continuous fabric envelope around both bent legs and off the floor."""
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);mesh=ev.to_mesh()
    cache={}
    def hull(z):
        band=round(z/.02)
        if band in cache:return cache[band]
        points=sorted(set((p.x,p.y) for p in leg_points if abs(p.z-band*.02)<.035))
        def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
        lo=[];hi=[]
        for p in points:
            while len(lo)>1 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
            lo.append(p)
        for p in reversed(points):
            while len(hi)>1 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
            hi.append(p)
        cache[band]=lo[:-1]+hi[:-1];return cache[band]
    for vertex in mesh.vertices:
        world=ev.matrix_world@vertex.co;desired=world.copy();desired.z=max(floor+.007,world.z)
        section=hull(desired.z)
        if len(section)>2:
            center=Vector((sum(p[0] for p in section)/len(section),sum(p[1] for p in section)/len(section),desired.z))
            direction=desired-center;direction.z=0
            if direction.length>.001:
                direction.normalize();radius=10
                for i,a in enumerate(section):
                    b=section[(i+1)%len(section)];normal=Vector((b[1]-a[1],a[0]-b[0],0));denominator=normal.dot(direction)
                    if denominator>1e-8:radius=min(radius,normal.dot(Vector((a[0],a[1],desired.z))-center)/denominator)
                if (desired-center).length<radius+.018:desired=center+direction*(radius+.018)
        shift=desired-world
        if shift.length<.00001:continue
        blend=Matrix.Identity(4)*0;total=0
        for assignment in obj.data.vertices[vertex.index].groups:
            bone=rig.pose.bones.get(obj.vertex_groups[assignment.group].name)
            if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*assignment.weight;total+=assignment.weight
        transform=(rig.matrix_world@(blend*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world).to_3x3()
        key.data[vertex.index].co+=transform.inverted_safe()@shift
    ev.to_mesh_clear()

def fit_river_cloth(root, rig, body, objects):
    data=json.loads((root/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    inverse=conversion.inverted()
    # Each imported bone may include the glTF bind-axis correction. Preserve it.
    corrections={name:(conversion@Matrix(rest)@inverse).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
    rig.animation_data_clear();rig.data.pose_position='POSE'
    for obj in objects:
        if not obj.data.shape_keys: obj.shape_key_add(name='Basis')
    for sample,pose in enumerate(data['poses']):
        for bone in rig.pose.bones:
            if bone.name in pose['bones']:
                bone.matrix=conversion@Matrix(pose['bones'][bone.name])@inverse@corrections[bone.name]
        bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
        points=[ev.matrix_world@v.co for v in mesh.vertices]
        tree=BVHTree.FromPolygons(points,[tuple(p.vertices) for p in mesh.polygons])
        leg_groups={g.index for g in body.vertex_groups if g.name=='pelvis' or g.name.startswith(('thigh_','calf_','foot_'))}
        foot_groups={g.index for g in body.vertex_groups if g.name.startswith(('foot_','toe'))}
        leg_points=[points[v.index] for v in mesh.vertices if sum(g.weight for g in v.groups if g.group in leg_groups)>.5]
        feet=[points[v.index].z for v in mesh.vertices if sum(g.weight for g in v.groups if g.group in foot_groups)>.5]
        floor=min(feet) if feet else min(p.z for p in points)
        ev.to_mesh_clear()
        for obj in objects:
            key=obj.shape_key_add(name='River cloth %03d'%sample);key.value=1
            _fit_pose(rig,obj,tree,key)
            if obj.name in ["Wrapped sari lower drape","Sari lower border"]:wrap_lower(rig,obj,key,leg_points,floor)
            key.value=0
        print('RIVER_CLOTH_SAMPLE',sample,flush=True)
    for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    rig.data.pose_position='REST'
