"""Local cloth-only relaxation without projecting the whole garment again."""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from river_surface_binding import inverse_skin
from river_triangle_contact import crosses
from purpose_cloth_volume import inside_surface


def relax(rig, obj, body, key, limit_point=None, candidate_clear=None):
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = ev.to_mesh(); mesh.calc_loop_triangles()
    points = [ev.matrix_world @ vertex.co for vertex in mesh.vertices]
    faces = [tuple(tri.vertices) for tri in mesh.loop_triangles]
    ev.to_mesh_clear()
    initial = [point.copy() for point in points]
    neighbors = [set() for point in points]
    for face in faces:
        for i in face:
            neighbors[i].update(j for j in face if j != i)

    def hits(values):
        tree = BVHTree.FromPolygons(values, faces, all_triangles=True)
        result = []
        for a, b in tree.overlap(tree):
            if a >= b or set(faces[a]) & set(faces[b]):
                continue
            if crosses([values[i] for i in faces[a]], [values[i] for i in faces[b]]):
                result.append((a, b))
        return result

    current = hits(points)
    if current:
        from collections import Counter
        basis = obj.data.shape_keys.reference_key.data
        regions = Counter()
        for pair in current:
            for face in pair:
                center = sum((basis[i].co for i in faces[face]), Vector()) / 3
                regions[round(center.z / .05) * 5] += 1
        print('OCCUPATION_CROSSING_HEIGHT_CM', obj.name, sorted(regions.items()), flush=True)
    if len(current) > 50:
        raise RuntimeError('Local relaxation refuses widespread cloth intersections')
    inverse = inverse_skin(rig, obj)
    for iteration in range(24):
        print('OCCUPATION_LOCAL_RELAX', obj.name, iteration, len(current), flush=True)
        if not current:
            for i, point in enumerate(points):
                key.data[i].co = inverse[i] @ point
            obj.data.update(); obj.update_tag(refresh={'DATA'})
            bpy.context.view_layer.update()
            return iteration
        affected = {i for pair in current for face in pair for i in faces[face]}
        affected |= {j for i in tuple(affected) for j in neighbors[i]}
        best = None
        for alpha in (.12, .25, .4, .6):
            candidate = [point.copy() for point in points]
            moved = False
            for i in affected:
                adjacent = neighbors[i]
                if not adjacent:
                    continue
                mean = sum((points[j] for j in adjacent), Vector()) / len(adjacent)
                target = points[i].lerp(mean, alpha)
                delta = target - initial[i]
                if delta.length > .015:
                    target = initial[i] + delta.normalized() * .015
                if limit_point is not None:
                    target = limit_point(i, points[i], target)
                    if (target - initial[i]).length > .0150001:
                        continue
                # Reject inward motion instead of running the broad projection
                # that reintroduced folded triangles in the seated trial.
                if inside_surface(body, target):
                    continue
                candidate[i] = target
                moved |= (target - points[i]).length > .000001
            if not moved:
                continue
            if candidate_clear is not None and not candidate_clear(candidate, affected):
                continue
            remaining = hits(candidate)
            if len(remaining) <= len(current) and (best is None or len(remaining) < len(best[1])):
                best = candidate, remaining
        if best is None or len(best[1]) == len(current):
            for first, second in current[:12]:
                for moving, stationary in ((first, second), (second, first)):
                    a, b, c = (points[i] for i in faces[stationary])
                    normal = (b - a).cross(c - a).normalized()
                    for direction in (normal, -normal):
                        depth = min((points[i] - a).dot(direction) for i in faces[moving])
                        shift = direction * max(.001, .001 - depth)
                        if shift.length > .015:
                            continue
                        candidate = points.copy()
                        for i in faces[moving]:
                            target = points[i] + shift
                            if limit_point is not None:
                                target = limit_point(i, points[i], target)
                            if (target - initial[i]).length > .015 or inside_surface(body, target):
                                break
                            candidate[i] = target
                        else:
                            if candidate_clear is not None and not candidate_clear(candidate, faces[moving]):
                                continue
                            remaining = hits(candidate)
                            if len(remaining) < len(current) and (
                                best is None or len(remaining) < len(best[1])
                            ):
                                best = candidate, remaining
        if best is None:
            break
        points, current = best
    raise RuntimeError('Bounded local cloth relaxation did not clear all intersections')
