"""Bounded repair of real cloth/foundation crossings; preserve the full body."""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from river_surface_binding import inverse_skin
from river_triangle_contact import crosses
from purpose_cloth_volume import inside_surface

def fit_foundation_contacts(rig,obj,body,key,foundation_points,foundation_faces):
    bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
    points=[evaluated.matrix_world@vertex.co for vertex in mesh.vertices];evaluated.to_mesh_clear()
    initial=[point.copy() for point in points];inverse=inverse_skin(rig,obj)
    obj.data.calc_loop_triangles();faces=[tuple(face.vertices) for face in obj.data.loop_triangles]
    foundation=BVHTree.FromPolygons(foundation_points,foundation_faces,all_triangles=True)
    supports=[]
    for face in foundation_faces:
        a,b,c=[foundation_points[index] for index in face]
        centre=(a+b+c)/3;normal=(b-a).cross(c-a).normalized()
        near,body_normal,_,_=body.find_nearest(centre)
        outward=centre-near if (centre-near).length>.0001 else body_normal
        if normal.dot(outward)<0:normal=-normal
        supports.append((centre,normal))
    for iteration in range(12):
        cloth=BVHTree.FromPolygons(points,faces,all_triangles=True);changes=0
        for foundation_id,cloth_id in foundation.overlap(cloth):
            foundation_face=foundation_faces[foundation_id];cloth_face=faces[cloth_id]
            if not crosses([foundation_points[i] for i in foundation_face],[points[i] for i in cloth_face]):continue
            centre,normal=supports[foundation_id]
            triangle=[foundation_points[i] for i in foundation_face]
            original=[points[i] for i in cloth_face]
            # Separate the finite triangles, rather than projecting every
            # cloth corner onto the foundation triangle's infinite plane.
            # That plane can extend across the other side of the torso.
            low=0.0;high=None
            for distance in [.001,.002,.004,.008,.016,.032,.064]:
                if not crosses(triangle,[point+normal*distance for point in original]):
                    high=distance;break
                low=distance
            if high is None:raise RuntimeError('No bounded finite foundation triangle separation')
            for _ in range(8):
                mid=(low+high)*.5
                if crosses(triangle,[point+normal*mid for point in original]):low=mid
                else:high=mid
            shift=normal*(high+.006)
            for index in cloth_face:
                desired=points[index]+shift
                if (desired-initial[index]).length>.08:
                    raise RuntimeError('Foundation triangle repair exceeds8cm at cloth vertex '+str(index)+
                        ' displacement_m='+str((desired-initial[index]).length))
                key.data[index].co+=inverse[index].to_3x3()@(desired-points[index])
                points[index]=desired;changes+=1
        if not changes:break
    else:raise RuntimeError('Foundation triangle repair failed to converge')
    # Reject body penetration instead of allowing a second fitter to undo
    # the layering constraint. Acceptance audits retain the same2mm rule.
    samples=points+[sum((points[i] for i in face),Vector())/3 for face in faces]
    for index,point in enumerate(samples):
        _,_,_,distance=body.find_nearest(point)
        if distance>.002 and inside_surface(body,point):
            raise RuntimeError('Foundation repair penetrates body at sample '+str(index)+' depth_m='+str(distance))
    return max(((point-start).length for point,start in zip(points,initial)),default=0.0)
