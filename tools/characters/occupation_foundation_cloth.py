"""Disposable gradual cloth fit over the unchanged complete activity body."""
import bpy
from river_surface_binding import inverse_skin


def seated_foundation(rig, body, obj, key, set_pose, inner=None, *, shirt=False, animate_location=False):
    scene = bpy.context.scene
    old_frame = scene.frame_current
    original_action = rig.animation_data.action if rig.animation_data else None
    saved_pose = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    original_group = obj.vertex_groups.get('Study cloth waist pins')
    if original_group:
        raise RuntimeError('Study pin group already exists')
    pins = obj.vertex_groups.new(name='Study cloth waist pins')
    basis = obj.data.shape_keys.key_blocks['Basis']
    top = max((obj.matrix_world @ vertex.co).z for vertex in basis.data)
    indices = [i for i, vertex in enumerate(basis.data)
               if (obj.matrix_world @ vertex.co).z > top - .025]
    if len(indices) < 4:
        raise RuntimeError('Foundation has insufficient waistband pins')
    if shirt:
        indices = [i for i in indices if abs((obj.matrix_world @ basis.data[i].co).x) < .13]
    bottom=min((obj.matrix_world@vertex.co).z for vertex in basis.data)
    cuffs=[i for i,vertex in enumerate(basis.data) if (obj.matrix_world@vertex.co).z<bottom+.025]
    # A fitted elastic foundation needs a weak return across the fabric,
    # as well as its stronger waistband and leg-opening constraints.
    pins.add(list(range(len(basis.data))),.35,'REPLACE')
    if not shirt:
        pins.add(cuffs,.65,'REPLACE')
    if inner:
        for i, vertex in enumerate(basis.data):
            height = (obj.matrix_world @ vertex.co).z
            weight = max(.35, min(1.0, (.74 - height) / .18))
            if weight > .35:
                pins.add([i], weight, 'REPLACE')
    pins.add(indices, 1.0, 'REPLACE')
    print('OCCUPATION_CLOTH_PINS','waist',len(indices),'elastic_cuffs',len(cuffs),flush=True)
    coordinates=[tuple(round(c,6) for c in vertex.co) for vertex in basis.data]
    print('OCCUPATION_CLOTH_SEAMS','duplicate_vertices',len(coordinates)-len(set(coordinates)),flush=True)
    inner_collider = None
    inner_action = None
    cloth = None
    collider = None
    action = None
    points = None
    try:
        if rig.animation_data:
            rig.animation_data.action = None
        key.value = 0
        for frame, label in ((1, 'idle'), (60, 'seated'), (90, 'seated')):
            set_pose(rig, label)
            for bone in rig.pose.bones:
                bone.rotation_mode = 'QUATERNION'
                bone.keyframe_insert(data_path='rotation_quaternion', frame=frame,
                                     group=bone.name)
                if shirt or animate_location:
                    bone.keyframe_insert(data_path='location', frame=frame, group=bone.name)
        action = rig.animation_data.action
        if inner:
            inner_obj, inner_key = inner
            inner_keys = inner_obj.data.shape_keys
            previous_action = inner_keys.animation_data.action if inner_keys.animation_data else None
            if inner_keys.animation_data:
                inner_keys.animation_data.action = None
            for frame, value in ((1, 0), (60, 1), (90, 1)):
                inner_key.value = value
                inner_key.keyframe_insert(data_path='value', frame=frame)
            inner_action = inner_keys.animation_data.action
            inner_collider = inner_obj.modifiers.new('Study foundation collider', 'COLLISION')
            inner_obj.collision.thickness_outer = .003
        scene.frame_set(1)
        bpy.context.view_layer.update()
        if inner:
            from mathutils.bvhtree import BVHTree
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated_inner = inner_obj.evaluated_get(depsgraph)
            mesh = evaluated_inner.to_mesh()
            mesh.calc_loop_triangles()
            inner_surface = BVHTree.FromPolygons(
                [evaluated_inner.matrix_world @ vertex.co for vertex in mesh.vertices],
                [tuple(triangle.vertices) for triangle in mesh.loop_triangles],
                all_triangles=True,
            )
            evaluated_inner.to_mesh_clear()
            evaluated_outer = obj.evaluated_get(depsgraph)
            mesh = evaluated_outer.to_mesh()
            signed_gaps = []
            for vertex in mesh.vertices:
                point = evaluated_outer.matrix_world @ vertex.co
                nearest, normal, _, distance = inner_surface.find_nearest(point)
                if distance < .020:
                    signed_gaps.append((point - nearest).dot(normal))
            evaluated_outer.to_mesh_clear()
            print('OCCUPATION_INITIAL_LAYER_GAP', 'nearby', len(signed_gaps),
                  'inside', sum(gap < -.001 for gap in signed_gaps),
                  'under_6mm', sum(gap < .006 for gap in signed_gaps), flush=True)
        collider = body.modifiers.new('Study complete body collider', 'COLLISION')
        body.collision.thickness_outer = .006
        body.collision.thickness_inner = .001
        body.collision.cloth_friction = .5
        cloth = obj.modifiers.new('Study gradual foundation cloth', 'CLOTH')
        settings = cloth.settings
        settings.quality = 24
        settings.mass = .2
        settings.air_damping = 2
        settings.tension_stiffness = 20
        settings.compression_stiffness = 20
        settings.shear_stiffness = 10
        settings.bending_stiffness = .5
        settings.vertex_group_mass = pins.name
        settings.pin_stiffness = 1
        collisions = cloth.collision_settings
        collisions.use_collision = True
        collisions.distance_min = .003 if inner else .005
        collisions.collision_quality = 16
        collisions.use_self_collision = True
        collisions.self_distance_min = .005
        collisions.self_friction = .5
        cloth.point_cache.frame_start = 1
        cloth.point_cache.frame_end = 90
        for frame in range(1, 91):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = ev.to_mesh()
            if frame == 90:
                points = [ev.matrix_world @ vertex.co for vertex in mesh.vertices]
            ev.to_mesh_clear()
            if frame in (1, 30, 60, 90):
                print('OCCUPATION_CLOTH_FRAME', frame, 'pins', len(indices), flush=True)
    finally:
        if inner_collider:
            inner_obj.modifiers.remove(inner_collider)
        if inner_action:
            inner_keys.animation_data.action = previous_action
            bpy.data.actions.remove(inner_action)
            inner_key.value = 1
        if cloth:
            obj.modifiers.remove(cloth)
        if collider:
            body.modifiers.remove(collider)
        if rig.animation_data:
            rig.animation_data.action = original_action
        if action and action != original_action:
            bpy.data.actions.remove(action)
        obj.vertex_groups.remove(pins)
        scene.frame_set(old_frame)
        for name, matrix in saved_pose.items():
            rig.pose.bones[name].matrix_basis = matrix
        key.value = 1
        bpy.context.view_layer.update()
    if points is None:
        raise RuntimeError('Foundation cloth produced no final surface')
    raw=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());raw_mesh=raw.to_mesh()
    goals=[raw.matrix_world@vertex.co for vertex in raw_mesh.vertices];raw.to_mesh_clear()
    worst=max(range(len(points)),key=lambda i:(points[i]-goals[i]).length)
    print('OCCUPATION_CLOTH_DISPLACEMENT','vertex',worst,'rest',tuple(basis.data[worst].co),
          'goal',tuple(goals[worst]),'cloth',tuple(points[worst]),
          'waist_error_mm',max((points[i]-goals[i]).length for i in indices)*1000,flush=True)
    from mathutils import Vector
    from purpose_cloth_volume import VolumeSurface, inside_surface

    skin = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    skin_mesh = skin.to_mesh()
    skin_mesh.calc_loop_triangles()
    volume = VolumeSurface.FromPolygons(
        [skin.matrix_world @ vertex.co for vertex in skin_mesh.vertices],
        [tuple(triangle.vertices) for triangle in skin_mesh.loop_triangles],
        strict=True,
    )
    skin.to_mesh_clear()
    goal = goals[worst]
    directions = [
        Vector((x, y, z)).normalized()
        for x in (-1, 0, 1) for y in (-1, 0, 1) for z in (-1, 0, 1)
        if x or y or z
    ]
    directions.append((points[worst] - goal).normalized())
    exit_mm = None
    for distance_mm in range(0, 121, 5):
        for direction in directions:
            sample = goal + direction * (distance_mm / 1000)
            if volume.find_nearest(sample)[3] >= .003 and not inside_surface(volume, sample):
                exit_mm = distance_mm
                break
        if exit_mm is not None:
            break
    print('OCCUPATION_CLOTH_EXIT', worst, 'goal_inside', inside_surface(volume, goal),
          'first_sample_with_3mm_clearance_mm', exit_mm, flush=True)
    # Recover excessive drift where the original posed fabric provides a
    # clear return path. The independent garment audit still checks faces.
    recovered = 0
    for i, point in enumerate(points):
        drift = point - goals[i]
        if drift.length <= .075:
            continue
        target = goals[i] + drift.normalized() * .075
        samples = [point.lerp(target, step / 8) for step in range(1, 9)]
        if all(volume.find_nearest(sample)[3] >= .003
               and not inside_surface(volume, sample) for sample in samples):
            points[i] = target
            recovered += 1
    print('OCCUPATION_CLOTH_RECOVERED', recovered, flush=True)
    inverse = inverse_skin(rig, obj)
    for i, point in enumerate(points):
        key.data[i].co = inverse[i] @ point
    obj.data.update()
    obj.update_tag(refresh={'DATA'})
    bpy.context.view_layer.update()
