"""Continuous cloth attachments to the retained MPFB surface; no body edits."""
import bpy,json,math
import numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree

def bind_surface(obj,body,rest_body,human_indices):
    rest_body.calc_loop_triangles()
    faces=[tuple(triangle.vertices) for triangle in rest_body.loop_triangles if all(i in human_indices for i in triangle.vertices)]
    points=[body.matrix_world@vertex.co for vertex in rest_body.vertices]
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
    bindings=[]
    for vertex in obj.data.vertices:
        point=obj.matrix_world@vertex.co
        near,normal,face,_=tree.find_nearest(point);a,b,c=faces[face]
        v0=points[b]-points[a];v1=points[c]-points[a];v2=near-points[a]
        denominator=v0.dot(v0)*v1.dot(v1)-v0.dot(v1)**2
        u=(v1.dot(v1)*v2.dot(v0)-v0.dot(v1)*v2.dot(v1))/max(denominator,1e-16)
        v=(v0.dot(v0)*v2.dot(v1)-v0.dot(v1)*v2.dot(v0))/max(denominator,1e-16)
        gap=max(.015 if obj.name=='Opaque fitted bra and thong foundation' else .025,(point-near).dot(normal))
        if obj.name=='Woven sari pallu over blouse':gap=min(.04,gap)
        bindings.append([a,b,c,1-u-v,u,v,gap])
    obj['river_surface_bindings']=json.dumps(bindings)

def inverse_skin(rig,obj):
    result=[]
    for vertex in obj.data.vertices:
        matrix=Matrix.Identity(4)*0;total=0
        for assignment in vertex.groups:
            bone=rig.pose.bones.get(obj.vertex_groups[assignment.group].name)
            if bone:matrix+=(bone.matrix@bone.bone.matrix_local.inverted())*assignment.weight;total+=assignment.weight
        transform=rig.matrix_world@(matrix*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world
        result.append(transform.inverted_safe())
    return result

def apply_surface(rig,obj,key,body_points,body_normals):
    transforms=inverse_skin(rig,obj)
    bindings=json.loads(obj['river_surface_bindings'])
    for index,(a,b,c,wa,wb,wc,gap) in enumerate(bindings):
        point=body_points[a]*wa+body_points[b]*wb+body_points[c]*wc
        normal=(body_normals[a]*wa+body_normals[b]*wb+body_normals[c]*wc).normalized()
        key.data[index].co=transforms[index]@(point+normal*gap)

def wrap_surface(rig,obj,key,leg_points,floor,slope,leg_surface):
    """Preserve ring directions over exact horizontal sections of the two legs."""
    inverse=inverse_skin(rig,obj);basis=obj.data.shape_keys.key_blocks['Basis']
    for vertex,rest in zip(key.data,basis.data):vertex.co=rest.co
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    points=[ev.matrix_world@vertex.co for vertex in mesh.vertices];ev.to_mesh_clear()
    top=max(point.z for point in points);bottom=min(point.z for point in points)
    rest_top=max(vertex.co.z for vertex in basis.data);rest_bottom=min(vertex.co.z for vertex in basis.data)
    triangles=np.asarray(leg_surface,dtype=np.float64);sections={}
    def section(z):
        stamp=round(z/.01);slice_z=stamp*.01
        if stamp not in sections:
            crossings=[]
            for a,b in [(0,1),(1,2),(2,0)]:
                left=triangles[:,a];right=triangles[:,b]
                selected=((left[:,2]<=slice_z)&(right[:,2]>slice_z))|((right[:,2]<=slice_z)&(left[:,2]>slice_z))
                left=left[selected];right=right[selected]
                if len(left):crossings.extend((left+(right-left)*((slice_z-left[:,2])/(right[:,2]-left[:,2]))[:,None])[:,:2].tolist())
            if not crossings:crossings=[(point.x,point.y) for point in leg_points if abs(point.z-slice_z)<.035]
            values=sorted(set(tuple(round(v,6) for v in point) for point in crossings))
            def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
            low=[];high=[]
            for point in values:
                while len(low)>1 and cross(low[-2],low[-1],point)<=0:low.pop()
                low.append(point)
            for point in reversed(values):
                while len(high)>1 and cross(high[-2],high[-1],point)<=0:high.pop()
                high.append(point)
            polygon=low[:-1]+high[:-1]
            if len(polygon)<3:sections[stamp]=None
            else:
                center=Vector(((min(p[0] for p in polygon)+max(p[0] for p in polygon))*.5,(min(p[1] for p in polygon)+max(p[1] for p in polygon))*.5,z))
                sections[stamp]=(center,polygon)
        return sections[stamp]
    for index,point in enumerate(points):
        contact=floor+slope*point.y+.018
        scale=max(.07,min(1.0,(top-contact)/max(.001,top-bottom)))
        progress=(rest_top-basis.data[index].co.z)/max(.001,rest_top-rest_bottom)
        z=top-progress*(top-bottom)*scale
        theta=math.atan2(basis.data[index].co.y,basis.data[index].co.x)
        direction=Vector((math.cos(theta),math.sin(theta),0))
        ring=section(z);desired=Vector((point.x,point.y,z))
        if ring:
            center,polygon=ring;radius=10.0
            for i,a in enumerate(polygon):
                b=polygon[(i+1)%len(polygon)];normal=Vector((b[1]-a[1],a[0]-b[0],0));denominator=normal.dot(direction)
                if denominator>1e-8:radius=min(radius,normal.dot(Vector((a[0],a[1],z))-center)/denominator)
            rest_radius=math.hypot(basis.data[index].co.x,basis.data[index].co.y)
            desired=center+direction*max(radius+.025,rest_radius);desired.z=z
        key.data[index].co=inverse[index]@desired
