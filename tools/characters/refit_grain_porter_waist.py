"""Build and audit an isolated waist-fold candidate from the workman_03 blend."""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

POSES = ((0, 0), (.20, 0), (.34, 0), (.34, .30), (.34, -.30),
         (0, .35), (0, -.35), (-.16, 0))
CONTACT_NAMES = (
    "Fitted cotton upper base", "Street opaque foundation",
    "Street folded dhoti l", "Street folded dhoti r",
    "village_farmer_MakeHuman_body",
)


def set_pose(rig, lean, twist):
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    for name, factor in (("spine_01", .45), ("spine_02", .55)):
        bone = rig.pose.bones[name]
        inverse = bone.bone.matrix_local.to_3x3().inverted()
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = (
            Quaternion((inverse @ Vector((1, 0, 0))).normalized(), lean * factor)
            @ Quaternion((inverse @ Vector((0, 0, 1))).normalized(), twist * factor)
        )
    bpy.context.view_layer.update()


def evaluated_surface(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        mesh.calc_loop_triangles()
        faces = [tuple(triangle.vertices) for triangle in mesh.loop_triangles]
        return points, BVHTree.FromPolygons(points, faces, all_triangles=True)
    finally:
        evaluated.to_mesh_clear()


def radial_direction(point):
    return Vector((point.x, point.y + .007, 0)).normalized()


def sample(rig, fold, layers, upper, pose):
    set_pose(rig, *pose)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points, fold_surface = evaluated_surface(fold, depsgraph)
    surfaces = [evaluated_surface(layer, depsgraph)[1] for layer in layers]
    gaps = {}
    for index in upper:
        point = points[index]
        axis = radial_direction(point)
        center = Vector((0, -.007, point.z))
        hit = surfaces[0].ray_cast(center + axis * .45, -axis, .45)[0]
        if hit is not None:
            gaps[index] = (point - hit).dot(axis)
    counts = tuple(len(fold_surface.overlap(surface)) for surface in surfaces)
    wrap_contact = tuple(len(surfaces[wrap].overlap(surfaces[layer]))
                         for wrap in (2, 3) for layer in (0, 1, 4))
    return gaps, counts + wrap_contact


def export_preview(path, rig, body):
    # Match the street variant exporter: bake the body without its helper
    # geometry, keeping the human surface, rig and separate foundation.
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    geometry = bpy.data.meshes.new_from_object(
        body.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph)
    export_body = bpy.data.objects.new(body.name + "_export_cutout", geometry)
    bpy.context.collection.objects.link(export_body)
    for group in body.vertex_groups:
        export_body.vertex_groups.new(name=group.name)
    export_body.parent = rig
    export_body.matrix_parent_inverse = body.matrix_parent_inverse.copy()
    export_body.matrix_basis = body.matrix_basis.copy()
    export_body.modifiers.new("Original MPFB rig", "ARMATURE").object = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj != body:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_animations=False, export_skins=True, export_all_influences=True,
        export_cameras=False, export_lights=False, export_morph=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--preview-glb", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    current = Path(bpy.data.filepath).resolve()
    target = args.candidate.resolve()
    if target == current or target.exists() or target.suffix != ".blend":
        parser.error("use a new .blend path for the isolated candidate")
    if args.preview_glb:
        preview = args.preview_glb.resolve()
        if preview.exists() or preview.suffix != ".glb":
            parser.error("use a new .glb path for the preview export")

    rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    fold = bpy.data.objects["Street dhoti waist fold"]
    layers = [bpy.data.objects[name] for name in CONTACT_NAMES]
    bind = fold.matrix_world.copy()
    upper = [vertex.index for vertex in fold.data.vertices if (bind @ vertex.co).z > 1.010]
    if len(upper) != 48:
        raise RuntimeError("unexpected porter waist mesh")
    pose_mode = rig.data.pose_position
    rig.data.pose_position = "POSE"
    original_pose = [(bone, bone.rotation_mode, bone.matrix_basis.copy()) for bone in rig.pose.bones]
    before = [sample(rig, fold, layers, upper, pose) for pose in POSES]
    def angle(point):
        return math.atan2(point.y + .007, point.x) % math.tau

    profile = sorted((angle(bind @ fold.data.vertices[index].co),
                      min(.040, max(0.0, min(gaps[index] for gaps, _ in before) - .021)))
                     for index in upper)
    profile = [(profile[-1][0] - math.tau, profile[-1][1]), *profile,
               (profile[0][0] + math.tau, profile[0][1])]

    def reduction(point):
        heading = angle(point)
        for (left, low), (right, high) in zip(profile, profile[1:]):
            if left <= heading <= right:
                return low + (high - low) * (heading - left) / (right - left)
        raise RuntimeError("missing waist profile sector")

    # Taper the full fold into its existing overlap with the leg wraps.
    # Moving the wraps inward increased their intersections with the body.
    inverse = bind.inverted()
    for vertex in fold.data.vertices:
        point = bind @ vertex.co
        height = max(0.0, min(1.0, (point.z - .943) / .075))
        amount = reduction(point) * height * height * (3.0 - 2.0 * height)
        vertex.co = inverse @ (point - radial_direction(point) * amount)
    fold.data.update()
    after = [sample(rig, fold, layers, upper, pose) for pose in POSES]
    for pose, (old, old_hits), (new, new_hits) in zip(POSES, before, after):
        print(f"WAIST_FIT {pose} worst_gap_mm={max(old.values())*1000:.1f}->{max(new.values())*1000:.1f} "
              f"minimum_mm={min(new.values())*1000:.1f} overlaps={old_hits}->{new_hits}")
        if len(new) != len(upper) or min(new.values()) < .005:
            raise RuntimeError("candidate top edge lost its shirt clearance")
        tested_contacts = (0, 1, 4, *range(5, len(new_hits)))
        if any(new_hits[index] > old_hits[index] for index in tested_contacts):
            raise RuntimeError("candidate increased intersections with shirt, foundation or body")
    for bone, mode, matrix in original_pose:
        bone.rotation_mode = mode
        bone.matrix_basis = matrix
    rig.data.pose_position = pose_mode
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(target), copy=True)
    if args.preview_glb:
        export_preview(preview, rig, layers[-1])


if __name__ == "__main__":
    main()
