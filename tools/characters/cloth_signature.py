"""Reject corrective banks authored against different fabric geometry or weights."""
import hashlib
import struct

def geometry_signature(obj):
    digest = hashlib.sha256()
    points = obj.data.shape_keys.key_blocks[0].data if obj.data.shape_keys else obj.data.vertices
    for index, point in enumerate(points):
        digest.update(struct.pack('<3f', *point.co))
        groups = sorted((obj.vertex_groups[g.group].name, g.weight) for g in obj.data.vertices[index].groups)
        for name, weight in groups:
            digest.update(name.encode('utf8') + b'\0' + struct.pack('<f', weight))
        digest.update(b'\n')
    for face in obj.data.polygons:
        digest.update(struct.pack('<I', len(face.vertices)))
        digest.update(struct.pack('<' + 'I' * len(face.vertices), *face.vertices))
    return digest.hexdigest()
