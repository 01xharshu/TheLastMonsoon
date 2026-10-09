"""Pose-local outward cloth fitting over the unchanged complete MPFB volume."""
import bpy
from mathutils import Matrix,Vector
from purpose_cloth_volume import inside_surface

def fit_key(rig,obj,tree,key,floor=None,slope=0.0,reset_key=True):
    basis=obj.data.shape_keys.key_blocks['Basis']
    if reset_key:
        for i in range(len(key.data)):key.data[i].co=basis.data[i].co
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(p.vertices) for p in mesh.polygons];ev.to_mesh_clear()
    inverse_transforms=[];offsets=[0.0]*len(points)
    for vertex in obj.data.vertices:
        blend=Matrix.Identity(4)*0;total=0
        for group in vertex.groups:
            bone=rig.pose.bones.get(obj.vertex_groups[group.group].name)
            if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*group.weight;total+=group.weight
        transform=(rig.matrix_world@(blend*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world).to_3x3()
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
    def correction(point):
        inside,distance=state(point)
        if not inside and distance>=.004:return Vector()
        near,normal,_,_=tree.find_nearest(point)
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
        points[index]+=shift
        key.data[index].co+=inverse_transforms[index]@shift
        offsets[index]+=shift.length
    for iteration in range(48):
        hits=0
        for index,point in enumerate(points):
            shift=correction(point)
            if shift.length>.001:apply(index,shift);hits+=1
        for face in faces:
            point=sum((points[i] for i in face),Vector())/len(face)
            shift=correction(point)
            if shift.length>.001:
                for index in face:apply(index,shift)
                hits+=1
        if not hits:break
    else:print('RIVER_LOCAL_FIT_LIMIT',obj.name,key.name,flush=True)
    return max(offsets,default=0.0)
