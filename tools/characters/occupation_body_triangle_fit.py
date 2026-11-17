"""Resolve body triangles protruding between otherwise clear fabric probes."""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from occupation_layered_fit import surface
from purpose_cloth_volume import VolumeSurface, inside_surface
from river_surface_binding import inverse_skin
from river_triangle_contact import crosses


def clear_body_triangles(rig, cloth, key, skin_points, skin_faces, limit_point):
    skin_tree = BVHTree.FromPolygons(skin_points, skin_faces, all_triangles=True)
    volume = VolumeSurface.FromPolygons(skin_points, skin_faces, strict=True)
    _, points, faces = surface(cloth, with_faces=True)
    inverse = inverse_skin(rig, cloth)
    neighbors = [set() for _ in points]
    vertex_faces = [set() for _ in points]
    for face_index, face in enumerate(faces):
        for index in face:
            neighbors[index].update(other for other in face if other != index)
            vertex_faces[index].add(face_index)

    def intersections(candidate, face_indices=None):
        if face_indices is None:
            face_indices = list(range(len(faces)))
        selected = [faces[index] for index in face_indices]
        tree = BVHTree.FromPolygons(candidate, selected, all_triangles=True)
        contacts = {}
        for left, right in tree.overlap(skin_tree):
            triangle = [candidate[i] for i in selected[left]]
            skin = [skin_points[i] for i in skin_faces[right]]
            if crosses(triangle, skin):
                contacts.setdefault(face_indices[left], []).append(skin)
        return contacts

    def body_clear(candidate, affected):
        face_ids = {face for i in affected for face in vertex_faces[i]}
        probes = [candidate[i] for i in affected]
        probes.extend(sum((candidate[i] for i in faces[face]), Vector()) / 3 for face in face_ids)
        return all(volume.find_nearest(point)[3] <= .001 or not inside_surface(volume, point)
                   for point in probes)

    directions = [Vector((x, y, z)).normalized()
                  for x in (-1, 0, 1) for y in (-1, 0, 1) for z in (-1, 0, 1) if x or y or z]
    contacts = intersections(points)
    for iteration in range(16):
        count = sum(map(len, contacts.values()))
        print('OCCUPATION_BODY_TRIANGLE_FIT', cloth.name, iteration, count, flush=True)
        if not count:
            for index, point in enumerate(points):
                key.data[index].co = inverse[index] @ point
            cloth.data.update()
            cloth.update_tag(refresh={'DATA'})
            bpy.context.view_layer.update()
            return
        shifts = [Vector() for _ in points]
        weights = [0 for _ in points]
        for face_index, skin_triangles in contacts.items():
            indices = faces[face_index]
            a, b, c = [points[index] for index in indices]
            normal = (b - a).cross(c - a).normalized()
            depth = max((vertex - a).dot(normal) for triangle in skin_triangles for vertex in triangle)
            shift = normal * min(.009, max(.0015, depth + .0015))
            for index in indices:
                shifts[index] += shift
                weights[index] += 1
        direct = [shift / count if count else Vector() for shift, count in zip(shifts, weights)]
        smoothed = direct.copy()
        for index, adjacent in enumerate(neighbors):
            if not weights[index] and adjacent:
                smoothed[index] = sum((direct[i] for i in adjacent), Vector()) * (.6 / len(adjacent))
        best = None
        for field in (smoothed, direct):
            for scale in (1.0, .5, .25):
                candidate = [limit_point(i, point, point + field[i] * scale)
                             for i, point in enumerate(points)]
                remaining = intersections(candidate)
                score = sum(map(len, remaining.values()))
                changed = {i for i, shift in enumerate(field) if shift.length > .000001}
                if score < count and (best is None or score < best[0]) and body_clear(candidate, changed):
                    best = score, candidate, remaining
        if best is None:
            for face in list(contacts)[:8]:
                center = set(faces[face])
                patch = center | {other for i in center for other in neighbors[i]}
                affected_faces = sorted({f for i in patch for f in vertex_faces[i]})
                unchanged = {i: crossing for i, crossing in contacts.items() if i not in affected_faces}
                for distance in (.0015, .003, .006, .009):
                    for direction in directions:
                        candidate = points.copy()
                        for i in patch:
                            scale = 1.0 if i in center else .4
                            candidate[i] = limit_point(i, points[i], points[i] + direction * (scale * distance))
                        remaining = unchanged | intersections(candidate, affected_faces)
                        score = sum(map(len, remaining.values()))
                        if score < count and (best is None or score < best[0]) and body_clear(candidate, patch):
                            best = score, candidate, remaining
                    if best is not None:
                        break
                if best is not None and best[0] == 0:
                    break
        if best is None:
            break
        _, points, contacts = best
    raise RuntimeError('Exact body triangle repair stalled: ' + cloth.name)
