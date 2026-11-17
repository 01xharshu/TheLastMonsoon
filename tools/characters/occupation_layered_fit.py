"""Ordered fitting for the disposable occupation study, preserving its body.

Fit each fabric layer independently, then copy its coordinates into the
study's original vertex order so the independent audit can reopen it.
"""
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from purpose_cloth_volume import VolumeSurface
from river_coherent_cloth import fit_key


def pose(rig, label):
    rig.data.pose_position = 'POSE'
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for side, sign in [('l', 1), ('r', -1)]:
        rotations = [('thigh_', -1.35), ('calf_', 1.5),
                     ('upperarm_', -.45), ('lowerarm_', -.85)] if label == 'seated' else [
                         ('thigh_', .30 * sign if label == 'walk' else 0),
                         ('upperarm_', .25 * sign if label == 'walk' else 0)]
        for prefix, angle in rotations:
            bone = rig.pose.bones.get(prefix + side)
            if bone:
                axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((1, 0, 0))
                bone.rotation_mode = 'QUATERNION'
                bone.rotation_quaternion = Quaternion(axis.normalized(), angle)
    bpy.context.view_layer.update()


def surface(obj, volume=False, with_faces=False):
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = ev.to_mesh()
    mesh.calc_loop_triangles()
    points = [ev.matrix_world @ vertex.co for vertex in mesh.vertices]
    faces = [tuple(tri.vertices) for tri in mesh.loop_triangles]
    ev.to_mesh_clear()
    tree = (VolumeSurface.FromPolygons(points, faces, strict=True) if volume else
            BVHTree.FromPolygons(points, faces, all_triangles=True))
    return (tree, points, faces) if with_faces else (tree, points)


def split(source, ids, name, rig):
    mapping = {old: new for new, old in enumerate(ids)}
    faces = [tuple(mapping[i] for i in face.vertices) for face in source.data.polygons
             if all(i in mapping for i in face.vertices)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([source.data.vertices[i].co.copy() for i in ids], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    obj.matrix_world = source.matrix_world.copy()
    for i, old in enumerate(ids):
        for assignment in source.data.vertices[old].groups:
            name = source.vertex_groups[assignment.group].name
            group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            group.add([i], assignment.weight, 'REPLACE')
    obj.modifiers.new('Original MPFB rig', 'ARMATURE').object = rig
    obj.shape_key_add(name='Basis')
    return obj


def guide_trousers(rig, trousers, key, foundation):
    from mathutils.kdtree import KDTree
    from river_surface_binding import inverse_skin

    indices = list(foundation.get('occupation_pattern_indices', []))
    if len(indices) != len(foundation.data.vertices):
        raise RuntimeError('Seated guide needs the original shared foundation pattern')
    evaluated = foundation.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    normal_matrix = evaluated.matrix_world.to_3x3().inverted().transposed()
    _, original = surface(trousers)
    deltas = {}
    samples = KDTree(len(indices))
    for vertex, index in zip(mesh.vertices, indices):
        normal = (normal_matrix @ vertex.normal).normalized()
        target = evaluated.matrix_world @ vertex.co + normal * .006
        deltas[index] = target - original[index]
        samples.insert(key.data[index].co, index)
    evaluated.to_mesh_clear()
    samples.balance()
    inverse = inverse_skin(rig, trousers)
    for i, vertex in enumerate(key.data):
        if i in deltas:
            displacement = deltas[i]
        else:
            neighbors = samples.find_n(vertex.co, 6)
            distance = neighbors[0][2]
            if distance >= .10:
                continue
            weights = [(index, 1 / max(gap, .004)**2) for _, index, gap in neighbors]
            total = sum(weight for _, weight in weights)
            displacement = sum((deltas[index] * (weight / total)
                                for index, weight in weights), Vector())
            displacement *= 1 - distance / .10
        vertex.co = inverse[i] @ (original[i] + displacement)
    trousers.data.update()
    trousers.update_tag(refresh={'DATA'})
    bpy.context.view_layer.update()


def round_trouser_knees(rig, trousers, key, body_tree):
    from purpose_cloth_volume import inside_surface
    from river_surface_binding import inverse_skin

    _, original = surface(trousers)
    inverse = inverse_skin(rig, trousers)
    basis = trousers.data.shape_keys.reference_key.data
    world = rig.matrix_world
    rig_space = world.inverted()
    half_length = .13
    for side in ('l', 'r'):
        thigh = rig.pose.bones['thigh_' + side]
        calf = rig.pose.bones['calf_' + side]
        knee = calf.bone.head_local
        axis = (calf.bone.tail_local - knee).normalized()
        upper_rotation = (thigh.matrix @ thigh.bone.matrix_local.inverted()).to_quaternion()
        lower_rotation = (calf.matrix @ calf.bone.matrix_local.inverted()).to_quaternion()
        start = calf.head - (upper_rotation @ axis) * half_length
        end = calf.head + (lower_rotation @ axis) * half_length
        for i, vertex in enumerate(basis):
            point = rig_space @ (trousers.matrix_world @ vertex.co)
            offset = point - knee
            along = offset.dot(axis)
            radial = offset - axis * along
            if abs(along) >= half_length or radial.length > .14:
                continue
            if (point.x - knee.x) ** 2 > (point.x + knee.x) ** 2:
                continue
            t = (along / half_length + 1) / 2
            center = start.lerp(calf.head, t).lerp(calf.head.lerp(end, t), t)
            rotation = upper_rotation.slerp(lower_rotation, t)
            target = world @ (center + rotation @ radial)
            blend = min(1.0, (half_length - abs(along)) / .035)
            target = original[i].lerp(target, blend)
            if inside_surface(body_tree, target):
                nearest, normal, _, _ = body_tree.find_nearest(target)
                exterior = nearest + normal * .003
                if not inside_surface(body_tree, exterior):
                    target = exterior
            key.data[i].co = inverse[i] @ target
    trousers.data.update()
    trousers.update_tag(refresh={'DATA'})
    bpy.context.view_layer.update()


def clear_body_contacts(rig, obj, key, body_tree, limit_point=None):
    from purpose_cloth_volume import inside_surface
    from river_surface_binding import inverse_skin

    inverse = inverse_skin(rig, obj)
    total = 0
    for iteration in range(6):
        _, points, faces = surface(obj, with_faces=True)
        samples = [((i,), point) for i, point in enumerate(points)]
        samples.extend((face, sum((points[i] for i in face), Vector()) / 3) for face in faces)
        corrections = [Vector() for point in points]
        counts = [0 for point in points]
        bad = 0
        for indices, point in samples:
            near, normal, _, distance = body_tree.find_nearest(point)
            if distance <= .001 or not inside_surface(body_tree, point):
                continue
            candidates = [near + normal * .003, near - normal * .003]
            candidates = [target for target in candidates
                          if (target - point).length <= .020 and not inside_surface(body_tree, target)]
            if not candidates:
                for radius in (.004, .008, .012, .016, .019):
                    for x in (-1, 0, 1):
                        for y in (-1, 0, 1):
                            for z in (-1, 0, 1):
                                if not (x or y or z):
                                    continue
                                direction = Vector((x, y, z)).normalized()
                                target = point + direction * radius
                                if not inside_surface(body_tree, target):
                                    candidates.append(target)
                    if candidates:
                        break
            if not candidates:
                raise RuntimeError('No bounded exterior cloth/body correction at ' +
                                   str(tuple(point)) + ' gap_mm=' + str(distance * 1000))
            target = min(candidates, key=lambda value: (value - point).length)
            for i in indices:
                corrections[i] += target - point
                counts[i] += 1
            bad += 1
        if not bad:
            print('OCCUPATION_BODY_CONTACTS', obj.name, total, flush=True)
            return total
        total += bad
        for i, count in enumerate(counts):
            if not count:
                continue
            target = points[i] + corrections[i] * (.8 / count)
            if limit_point is not None:
                target = limit_point(i, points[i], target)
            key.data[i].co = inverse[i] @ target
        obj.data.update()
        obj.update_tag(refresh={'DATA'})
        bpy.context.view_layer.update()
    raise RuntimeError('Bounded cloth/body contact correction did not converge')


def freeze_triangles(obj):
    """Keep the same cloth diagonals in fitting, deformed audit and export."""
    import bmesh

    if obj.data.shape_keys:
        raise RuntimeError('Cloth triangulation must precede pose keys')
    original = [vertex.co.copy() for vertex in obj.data.vertices]
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.triangulate(mesh, faces=list(mesh.faces))
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    if len(original) != len(obj.data.vertices) or any(
        (vertex.co - original[i]).length > .0000001
        for i, vertex in enumerate(obj.data.vertices)
    ):
        raise RuntimeError('Cloth triangulation changed vertex correspondence')
    print('OCCUPATION_FROZEN_TRIANGLES', obj.name, len(obj.data.polygons), flush=True)


def fit(rig, body, combined, foundation, upper_count, diagnostic=False, exact_layers=False, cloth_foundation=False, subdivide_foundation=False):
    if subdivide_foundation:
        if foundation.data.shape_keys:
            raise RuntimeError('Foundation subdivision must precede pose keys')
        import bmesh
        before=len(foundation.data.vertices)
        bm=bmesh.new();bm.from_mesh(foundation.data)
        bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=1,use_grid_fill=True)
        bm.to_mesh(foundation.data);bm.free();foundation.data.update()
        print('OCCUPATION_FOUNDATION_RESOLUTION',before,len(foundation.data.vertices),flush=True)
    freeze_triangles(combined)
    freeze_triangles(foundation)
    upper_ids = list(range(upper_count))
    lower_ids = list(range(upper_count, len(combined.data.vertices)))
    upper = split(combined, upper_ids, 'Study independent shirt', rig)
    lower = split(combined, lower_ids, 'Study independent trousers', rig)
    if exact_layers:
        basis = upper.data.shape_keys.reference_key.data
        pelvis = upper.matrix_world.inverted() @ (rig.matrix_world @ rig.data.bones['pelvis'].head_local)
        for i, vertex in enumerate(basis):
            point = vertex.co.copy()
            weight = max(0.0, min(1.0, (1.12 - point.z) / .14))
            arms = sum(assignment.weight for assignment in upper.data.vertices[i].groups
                       if any(part in upper.vertex_groups[assignment.group].name
                              for part in ('arm_', 'hand_', 'clavicle_')))
            if arms > .1 or not weight:
                continue
            radial = Vector((point.x - pelvis.x, point.y - pelvis.y, 0))
            if radial.length > .001:
                vertex.co = point + radial.normalized() * (.025 * weight)
        upper.data.update()
        upper.update_tag(refresh={'DATA'})
        bpy.context.view_layer.update()
        print('OCCUPATION_SHIRT_WAIST_EASE_MM', 25, flush=True)
    if exact_layers:
        basis = lower.data.shape_keys.reference_key.data
        original = [vertex.co.copy() for vertex in basis]
        for i, vertex in enumerate(lower.data.vertices):
            basis[i].co = original[i] + vertex.normal * .006
        lower.data.update()
        lower.update_tag(refresh={'DATA'})
        bpy.context.view_layer.update()
        print('OCCUPATION_TROUSER_EASE_MM', 6, flush=True)
    combined.shape_key_add(name='Basis')
    if not foundation.data.shape_keys:
        foundation.shape_key_add(name='Basis')
    limits = (.10, .10) if diagnostic else (.04, .05)
    for label in ('idle', 'walk', 'seated'):
        for obj in (upper, lower, foundation, combined):
            for key in obj.data.shape_keys.key_blocks:
                key.value = 0
        pose(rig, label)
        keys = {}
        for obj in (foundation, lower, upper):
            name = ('Basis' if label == 'idle' else
                    'Study ' + label + (' foundation' if obj == foundation else ' correction'))
            key = obj.data.shape_keys.key_blocks.get(name) or obj.shape_key_add(name=name)
            if label != 'idle':
                key.value = 1
            keys[obj] = key
        body_tree, _ = surface(body, volume=True)
        # Each stage sees the evaluated completed inner stage. Never fit two
        # mutually intersecting outer layers simultaneously against the skin.
        for index, obj in enumerate((foundation, lower, upper)):
            before = [vertex.co.copy() for vertex in keys[obj].data]
            _, before_pose = surface(obj)
            support = None if index == 0 else surface(foundation if index == 1 else lower)[0]
            if cloth_foundation and label == 'seated' and index == 1:
                guide_trousers(rig, obj, keys[obj], foundation)
                round_trouser_knees(rig, obj, keys[obj], body_tree)
            elif cloth_foundation and label == 'seated' and index == 0:
                from occupation_foundation_cloth import seated_foundation
                seated_foundation(rig, body, obj, keys[obj], pose,
                                  None)
            else:
                for finishing_pass in range(2):
                    fit_key(rig, obj, body_tree, keys[obj], reset_key=False,
                            foundation=None if exact_layers else support, minimum_clearance_m=.003, jacobi=True)
                    obj.data.update()
                    obj.update_tag(refresh={'DATA'})
                    bpy.context.view_layer.update()
            if cloth_foundation and label == 'seated' and index:
                cap = limits[1] - .001
                for vertex, original in zip(keys[obj].data, before):
                    displacement = vertex.co - original
                    if displacement.length > cap:
                        vertex.co = original + displacement.normalized() * cap
                obj.data.update()
                obj.update_tag(refresh={'DATA'})
                bpy.context.view_layer.update()
            limit_point = None
            if cloth_foundation and label == 'seated' and index:
                from river_surface_binding import inverse_skin
                from purpose_cloth_volume import inside_surface

                inverses = inverse_skin(rig, obj)
                forwards = [matrix.inverted() for matrix in inverses]

                def limit_point(i, current, target):
                    delta = inverses[i] @ target - before[i]
                    if delta.length > cap:
                        target = forwards[i] @ (before[i] + delta.normalized() * cap)
                    if inside_surface(body_tree, target) and not inside_surface(body_tree, current):
                        for fraction in (.5, .25, .125):
                            partial = current.lerp(target, fraction)
                            if not inside_surface(body_tree, partial):
                                return partial
                        return current
                    return target
            if exact_layers:
                from river_upper_self_fit import regularize_upper, self_hits
                obj.data.calc_loop_triangles()
                triangles=[tuple(t.vertices) for t in obj.data.loop_triangles]
                print('OCCUPATION_STAGE_SELF',label,obj.name,'before',self_hits(before_pose,triangles),'after_body',self_hits(surface(obj)[1],triangles),flush=True)
                from river_layer_fit import separate_layers
                from occupation_fit_constraints import ClothConstraints
                constraints = ClothConstraints(triangles, body_tree)
                if cloth_foundation and label == 'seated':
                    from occupation_cloth_relax import relax
                    _, initial_points = surface(obj)
                    initial_body_clear = constraints.body_clear(initial_points, range(len(initial_points)))
                    self_passes = relax(
                        rig, obj, body_tree, keys[obj], limit_point=limit_point,
                        candidate_clear=constraints.body_clear if initial_body_clear else None,
                    )
                else:
                    self_passes = regularize_upper(rig, obj, body_tree, keys[obj])
                if clear_body_contacts(rig, obj, keys[obj], body_tree, limit_point):
                    from occupation_cloth_relax import relax
                    self_passes += relax(
                        rig, obj, body_tree, keys[obj], limit_point=limit_point,
                        candidate_clear=constraints.body_clear,
                    )
                obj.data.update(); obj.update_tag(refresh={'DATA'})
                bpy.context.view_layer.update()
                layer_passes = 0
                if index:
                    inner = foundation if index == 1 else lower
                    inner_tree, inner_points, inner_faces = surface(inner, with_faces=True)
                    layer_passes = separate_layers(rig, obj, keys[obj], inner_points,
                                                  inner_faces, inner_tree, gap=.006,
                                                  reserve_margin=False, limit_point=limit_point,
                                                  slide_contacts=True, candidate_clear=constraints, minimum_gap=.003)
                    obj.data.update(); obj.update_tag(refresh={'DATA'})
                    bpy.context.view_layer.update()
                print('OCCUPATION_EXACT_LAYER', label, obj.name,
                      'self_passes', self_passes, 'layer_passes', layer_passes, flush=True)
            _, after_pose = surface(obj)
            bind_shift = max((vertex.co - before[i]).length for i, vertex in enumerate(keys[obj].data))
            posed_shift = max((point - before_pose[i]).length for i, point in enumerate(after_pose))
            print('OCCUPATION_ORDERED_LAYER', label, obj.name,
                  'bind_mm', bind_shift * 1000, 'posed_mm', posed_shift * 1000, flush=True)
            if bind_shift > limits[index > 0] or posed_shift > limits[index > 0]:
                raise RuntimeError('Ordered layer exceeded correction bound: ' + obj.name)
        name = 'Basis' if label == 'idle' else 'Study ' + label + ' correction'
        destination = combined.data.shape_keys.key_blocks.get(name) or combined.shape_key_add(name=name)
        for obj, ids in ((upper, upper_ids), (lower, lower_ids)):
            for new, old in enumerate(ids):
                destination.data[old].co = keys[obj].data[new].co.copy()
        combined.data.update()
    for obj in (combined, foundation):
        for key in obj.data.shape_keys.key_blocks:
            key.value = 0
        obj.data.update()
        obj.update_tag(refresh={'DATA'})
    for obj in (upper, lower):
        bpy.data.objects.remove(obj, do_unlink=True)
    pose(rig, 'idle')
    combined['occupation_upper_vertex_count'] = upper_count
    combined['ordered_layer_fit'] = True
    combined['exact_layer_fit'] = exact_layers
