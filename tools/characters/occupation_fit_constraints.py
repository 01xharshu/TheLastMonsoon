"""Exact self crossings and sampled body clearance for cloth solver proposals."""
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from purpose_cloth_volume import inside_surface
from river_triangle_contact import crosses


class ClothConstraints:
    def __init__(self, faces, body, body_triangles=None):
        self.faces = faces
        self.body = body
        self.skin_triangles = body_triangles
        self.skin_tree = (BVHTree.FromPolygons(*body_triangles, all_triangles=True)
                          if body_triangles is not None else None)
        self.vertex_faces = {}
        for face_index, face in enumerate(faces):
            for vertex in face:
                self.vertex_faces.setdefault(vertex, set()).add(face_index)

    def changed_faces(self, vertices):
        return sorted({face for vertex in vertices for face in self.vertex_faces[vertex]})

    def body_clear(self, points, vertices):
        faces = self.changed_faces(vertices)
        samples = [points[i] for i in vertices]
        samples.extend(sum((points[i] for i in self.faces[face]), Vector()) / 3
                       for face in faces)
        for point in samples:
            if self.body.find_nearest(point)[3] > .001 and inside_surface(self.body, point):
                return False
        if self.skin_tree is not None:
            skin_points, skin_faces = self.skin_triangles
            selected = [self.faces[i] for i in faces]
            patch = BVHTree.FromPolygons(points, selected, all_triangles=True)
            for cloth_face, skin_face in patch.overlap(self.skin_tree):
                cloth = [points[i] for i in selected[cloth_face]]
                skin = [skin_points[i] for i in skin_faces[skin_face]]
                if crosses(cloth, skin):
                    return False
        return True

    def __call__(self, points, vertices):
        changed = self.changed_faces(vertices)
        selected = [self.faces[face] for face in changed]
        tree = BVHTree.FromPolygons(points, self.faces, all_triangles=True)
        patch = BVHTree.FromPolygons(points, selected, all_triangles=True)
        for local, other in patch.overlap(tree):
            face = selected[local]
            opposite = self.faces[other]
            if set(face).intersection(opposite):
                continue
            if crosses([points[i] for i in face], [points[i] for i in opposite]):
                return False
        return self.body_clear(points, vertices)
