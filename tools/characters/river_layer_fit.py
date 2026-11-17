"""Separate actual intersecting cloth triangles without hiding human surfaces."""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from river_surface_binding import inverse_skin
from river_triangle_contact import crosses

def separate_layers(rig,obj,key,inner_points,inner_faces,inner_tree,gap=.010,clearance_trees=None,reserve_margin=True, limit_point=None, slide_contacts=False, candidate_clear=None, minimum_gap=0.0, allow_compression=False):
    obj.data.calc_loop_triangles();faces=[tuple(t.vertices) for t in obj.data.loop_triangles]
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    points=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
    inverse_full = inverse_skin(rig, obj)
    inverse = [matrix.to_3x3() for matrix in inverse_full]
    def move(index, shift):
        if limit_point is not None or candidate_clear is not None:
            target = points[index] + shift
            if limit_point is not None:
                target = limit_point(index, points[index], target)
            points[index] = target
            key.data[index].co = inverse_full[index] @ target
        else:
            points[index] += shift
            key.data[index].co += inverse[index] @ shift
    # Reserve a small construction gap at the waistband before correcting
    # crossings. Off-key interpolation must not start from zero layer clearance.
    basis=obj.data.shape_keys.reference_key.data
    for clearance in (clearance_trees or [inner_tree]) if reserve_margin else []:
        for i,point in enumerate(points):
            if basis[i].co.z<.80:continue
            nearest,normal,_,distance=clearance.find_nearest(point)
            if nearest is None or distance>.030:continue
            signed=(point-nearest).dot(normal)
            if signed<.015:
                shift=normal*(.015-signed)
                move(i,shift)
    neighbors = [set() for point in points] if slide_contacts else []
    vertex_faces = [set() for point in points] if slide_contacts else []
    if slide_contacts:
        for face_id, face in enumerate(faces):
            for vertex in face:
                vertex_faces[vertex].add(face_id)
        for face in faces:
            for vertex in face:
                neighbors[vertex].update(other for other in face if other != vertex)

    def contact_patch(face, rings):
        depths = {vertex: 0 for vertex in face}
        frontier = set(face)
        for depth in range(1, rings + 1):
            frontier = {other for vertex in frontier for other in neighbors[vertex]} - depths.keys()
            depths.update((vertex, depth) for vertex in frontier)
        return {vertex: (rings + 1 - depth) / (rings + 1)
                for vertex, depth in depths.items()}

    clearance_samples = []
    if minimum_gap > 0:
        normals = [Vector() for point in inner_points]
        first_face = {}
        for face_id, face in enumerate(inner_faces):
            a, b, c = (inner_points[i] for i in face)
            normal = (b - a).cross(c - a)
            if normal.length < .00000001:
                continue
            clearance_samples.append(((a + b + c) / 3, normal.normalized(), face_id))
            for vertex in face:
                normals[vertex] += normal
                first_face.setdefault(vertex, face_id)
        clearance_samples.extend((point, normals[i].normalized(), first_face[i])
                                 for i, point in enumerate(inner_points)
                                 if normals[i].length > .00000001)

    def clearance_contacts(tree):
        contacts = []
        for point, normal, inner_face in clearance_samples:
            near, _, outer_face, distance = tree.find_nearest(point)
            if near is None or distance >= minimum_gap - .00001:
                continue
            separation = near - point
            signed = separation.dot(normal)
            if signed >= 0 and distance > .00001:
                shift = separation.normalized() * (minimum_gap - distance)
            else:
                shift = normal * (minimum_gap - signed)
            contacts.append((outer_face, inner_face, shift))
        return contacts

    def count_crossings(candidate, changed_vertices=None, contacts=None):
        if changed_vertices is None:
            changed_faces = list(range(len(faces)))
            unchanged = 0
        else:
            changed = {face for vertex in changed_vertices for face in vertex_faces[vertex]}
            changed_faces = sorted(changed)
            unchanged = sum(first not in changed for first, _ in contacts)
        selected = [faces[face] for face in changed_faces]
        tree = BVHTree.FromPolygons(candidate, selected, all_triangles=True)
        total = unchanged + sum(
            crosses([candidate[i] for i in selected[first]],
                    [inner_points[i] for i in inner_faces[second]])
            for first, second in tree.overlap(inner_tree)
        )
        if clearance_samples:
            full = BVHTree.FromPolygons(candidate, faces, all_triangles=True)
            total += len(clearance_contacts(full))
        return total

    for iteration in range(64 if slide_contacts else 32):
        tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
        contact_faces = []
        crossing_faces = []
        pending=[Vector() for p in points];counts=[0]*len(points);hits=0
        for first,second in tree.overlap(inner_tree):
            ids=faces[first];outer=[points[i] for i in ids];inner=[inner_points[i] for i in inner_faces[second]]
            if not crosses(outer,inner):continue
            normal=(inner[1]-inner[0]).cross(inner[2]-inner[0]).normalized()
            if normal.length<.5:continue
            shift=normal*(gap-min((point-inner[0]).dot(normal) for point in outer))
            for index in ids:pending[index]+=shift;counts[index]+=1
            hits+=1
            contact_faces.append((first, second))
            crossing_faces.append((first, second))
        for first, second, shift in clearance_contacts(tree):
            for vertex in faces[first]:
                pending[vertex] += shift
                counts[vertex] += 1
            hits += 1
            contact_faces.append((first, second))
        if not hits:
            if limit_point is not None:
                obj.data.update()
                obj.update_tag(refresh={'DATA'})
                bpy.context.view_layer.update()
                evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
                actual = evaluated.to_mesh()
                error = max((evaluated.matrix_world @ vertex.co - points[i]).length
                            for i, vertex in enumerate(actual.vertices))
                evaluated.to_mesh_clear()
                print('OCCUPATION_LAYER_TRACK_ERROR_MM', obj.name, error * 1000, flush=True)
                if error > .00005:
                    raise RuntimeError('Bounded layer surface differs from evaluated cloth')
            return iteration
        if candidate_clear is not None:
            changed = {i for i, count in enumerate(counts) if count}
            candidate = points.copy()
            for i in changed:
                target = points[i] + pending[i] * (.8 / counts[i])
                candidate[i] = limit_point(i, points[i], target) if limit_point is not None else target
            remaining = count_crossings(candidate)
            changed_enough = any((candidate[i] - points[i]).length > .00001 for i in changed)
            progressing = remaining < hits or (iteration < 8 and remaining == hits and changed_enough)
            if progressing and candidate_clear(candidate, changed):
                for i in changed:
                    move(i, candidate[i] - points[i])
                continue
        if slide_contacts and (limit_point is not None or candidate_clear is not None) and (iteration >= 16 or candidate_clear is not None):
            best_count = hits
            best = None
            for first, second in contact_faces[:16]:
                a, b, c = (inner_points[i] for i in inner_faces[second])
                normal = (b-a).cross(c-a).normalized()
                shifts = [
                    edge.normalized() * distance + normal * lift
                    for edge in (b-a, c-b, a-c)
                    for distance in (-.024, -.012, -.005, .005, .012, .024)
                    for lift in (0, .004)
                ]
                if minimum_gap > 0:
                    shifts.extend(normal * distance for distance in (.0005, .001, .002, .004, .008, -.001, -.002, -.004))
                    if hits <= 5:
                        shifts.extend(Vector(axis) * (step * sign)
                                      for axis in ((1, 0, 0), (0, 1, 0), (0, 0, 1))
                                      for step in (.0005, .001, .002, .004) for sign in (-1, 1))
                for rings in (1, 2, 3):
                    weights = contact_patch(faces[first], rings)
                    for shift in shifts:
                        candidate = points.copy()
                        for i, weight in weights.items():
                            target = points[i] + shift * weight
                            candidate[i] = limit_point(i, points[i], target) if limit_point is not None else target
                        remaining = count_crossings(candidate, weights, crossing_faces)
                        if remaining < best_count and (candidate_clear is None or candidate_clear(candidate, weights)):
                            best_count = remaining
                            best = (tuple(weights), candidate)
            if best is not None:
                ids, candidate = best
                if count_crossings(candidate) != best_count:
                    raise RuntimeError('Local and full garment crossing counts disagree')
                for i in ids:
                    move(i, candidate[i] - points[i])
                print('OCCUPATION_LAYER_SLIDE', obj.name, hits, best_count, flush=True)
                continue
        if candidate_clear is not None:
            break
        if slide_contacts and limit_point is not None and iteration >= 16:
            candidate = [
                limit_point(i, point, point + pending[i] * (.8 / counts[i]))
                if counts[i] else point
                for i, point in enumerate(points)
            ]
            if count_crossings(candidate) >= hits:
                break
            for i, point in enumerate(candidate):
                move(i, point - points[i])
        else:
            for index,count in enumerate(counts):
                if count:
                    shift=pending[index]*(.8/count)
                    move(index,shift)
    if limit_point is not None:
        heights = sorted(basis[i].co.z for face in {first for first, _ in contact_faces} for i in faces[face])
        print('OCCUPATION_LAYER_STALL', obj.name, 'constraints', hits, 'crossings', len(crossing_faces),
              'rest_z_range', (heights[0], heights[-1]), flush=True)
    if allow_compression and not crossing_faces:
        obj.data.update()
        obj.update_tag(refresh={'DATA'})
        bpy.context.view_layer.update()
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        actual = [evaluated.matrix_world @ point.co for point in mesh.vertices]
        evaluated.to_mesh_clear()
        if count_crossings(actual) > len(clearance_contacts(BVHTree.FromPolygons(actual, faces, all_triangles=True))):
            raise RuntimeError('Compressed evaluated fabric contains a crossing')
        print('OCCUPATION_LAYER_COMPRESSED', obj.name, hits, 'near points', flush=True)
        return iteration
    raise RuntimeError('Exact garment layer separation did not converge: '+obj.name+' '+key.name)
