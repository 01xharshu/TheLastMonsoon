"""Pose-local outward cloth fitting over the unchanged complete MPFB volume."""
import bpy
from mathutils import Matrix,Vector
from purpose_cloth_volume import inside_surface

def fit_key(rig,obj,tree,key,floor=None,slope=0.0,reset_key=True,foundation=None):
    basis=obj.data.shape_keys.key_blocks['Basis']
    if reset_key:
        for i in range(len(key.data)):key.data[i].co=basis.data[i].co
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    # Cropped garment faces can be quads or ngons. Check the same triangles
    # that the exporter uses; a polygon centre can miss an inward diagonal.
    obj.data.calc_loop_triangles()
    points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(p.vertices) for p in obj.data.loop_triangles];ev.to_mesh_clear()
    inverse_transforms=[];offsets=[0.0]*len(points)
    initial_points=[point.copy() for point in points]
    bone_transforms={group.index:bone.matrix@bone.bone.matrix_local.inverted() for group in obj.vertex_groups if (bone:=rig.pose.bones.get(group.name))}
    rig_world=rig.matrix_world.copy();rig_inverse=rig_world.inverted();object_world=obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        blend=Matrix.Identity(4)*0;total=0
        for group in vertex.groups:
            bone_transform=bone_transforms.get(group.group)
            if bone_transform is not None:blend+=bone_transform*group.weight;total+=group.weight
        transform=(rig_world@(blend*(1/total) if total else Matrix.Identity(4))@rig_inverse@object_world).to_3x3()
        inverse_transforms.append(transform.inverted_safe())
    if floor is not None:
        top=max(point.z for point in points)
        bottom=min(point.z for point in points)
        for index,point in enumerate(points):
            contact=floor+slope*point.y+.010
            if contact>bottom:
                scale=max(.06,min(1.0,(top-contact)/max(.001,top-bottom)))
                desired=top+(point.z-top)*scale
                shift=Vector((0,0,desired-point.z))
                # Preserve vertical ordering rather than crushing rings onto
                # one floor plane; the lower sari folds up as the hips lower.
                key.data[index].co+=inverse_transforms[index]@shift;points[index]+=shift
    cache={}
    def state(point):
        stamp=tuple(round(v,6) for v in point)
        if stamp not in cache:
            _,_,_,distance=tree.find_nearest(point)
            cache[stamp]=(inside_surface(tree,point),distance)
        return cache[stamp]
    axes=[Vector((x,y,z)).normalized() for x in [-1,0,1] for y in [-1,0,1] for z in [-1,0,1] if x or y or z]
    def foundation_constraint(point):
        if foundation is None:return None
        inside,distance=state(point)
        if distance>=.10:return None
        near,normal,_,_=tree.find_nearest(point)
        direction=(point-near).normalized() if not inside and distance>.0001 else normal
        cursor=near-direction*.0005;outer=None
        for _ in range(8):
            hit,_,_,_=foundation.ray_cast(cursor,direction,.04)
            if hit is None or (hit-near).dot(direction)>.04:break
            outer=hit;cursor=hit+direction*.0001
        return (outer,direction) if outer is not None else None
    # Freeze the finite foundation support before iterative movement. Updating
    # nearest-skin directions after each correction can produce opposing pulls.
    vertex_support=[foundation_constraint(point) for point in points]
    face_support=[foundation_constraint(sum((points[i] for i in face),Vector())/len(face)) for face in faces]
    def correction(point,support):
        inside,distance=state(point)
        near,normal,_,_=tree.find_nearest(point)
        if support is not None:
            outer,direction=support
            amount=.006-(point-outer).dot(direction)
            if amount>.001:
                direct=direction*amount
                occupied,gap=state(point+direct)
                if not occupied and gap>=.004:return direct
        if not inside and distance>=.004:return Vector()
        direct=near+normal*.008-point
        target_inside,target_distance=state(point+direct)
        if not target_inside and target_distance>=.004:return direct
        directions=[normal,(near-point).normalized()]+axes
        best=None
        for direction in directions:
            if direction.length<.5:continue
            low=0.0
            for step in [.008,.016,.032,.064,.128,.256,.512]:
                if best is not None and step>best.length*2:break
                occupied,gap=state(point+direction*step)
                if not occupied and gap>=.004:
                    high=step
                    for _ in range(7):
                        mid=(low+high)*.5;occupied,gap=state(point+direction*mid)
                        if not occupied and gap>=.004:high=mid
                        else:low=mid
                    shift=direction*high
                    if best is None or shift.length<best.length:best=shift
                    break
                low=step
        if best is None:raise RuntimeError('No bounded local garment exit '+obj.name+' '+key.name)
        return best
    def apply(index,shift):
        displacement=(points[index]+shift-initial_points[index]).length
        if foundation is not None and displacement>.20:
            raise RuntimeError('Foundation fit exceeded 20cm bounded correction at vertex '+str(index)+
                ' position='+str(tuple(points[index]))+' step='+str(tuple(shift))+
                ' displacement_m='+str(displacement)+' accumulated_m='+str(offsets[index])+'; refusing this candidate')
        points[index]+=shift
        key.data[index].co+=inverse_transforms[index]@shift
        offsets[index]+=shift.length
    for iteration in range(48):
        hits=0
        for index,point in enumerate(points):
            shift=correction(point,vertex_support[index])
            if shift.length>.001:apply(index,shift);hits+=1
        for face_index,face in enumerate(faces):
            point=sum((points[i] for i in face),Vector())/len(face)
            shift=correction(point,face_support[face_index])
            if shift.length>.001:
                for index in face:apply(index,shift)
                hits+=1
        if not hits:break
    else:
        if foundation is not None:raise RuntimeError('Foundation fit did not converge; refusing to export this candidate')
        print('RIVER_LOCAL_FIT_LIMIT',obj.name,key.name,flush=True)
    return max(offsets,default=0.0)
