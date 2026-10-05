"""Distinct fitted work-clothing studies over the unchanged MPFB bodies."""
import bpy
from mathutils import Vector


def apply(role, outfit, rig, material, body_surface=None):
    def arm_weight(vertex, obj, prefixes):
        indices = {g.index for g in obj.vertex_groups if g.name.startswith(prefixes)}
        return sum(g.weight for g in vertex.groups if g.group in indices)

    def mask(obj, name, keep):
        group = obj.vertex_groups.new(name=name)
        if keep:
            group.add(keep, 1.0, 'REPLACE')
        modifier = obj.modifiers.new(name, 'MASK')
        modifier.vertex_group = group.name

    def copy_garment(name, color):
        obj = outfit.copy()
        obj.data = outfit.data.copy()
        bpy.context.collection.objects.link(obj)
        obj.name = name
        obj.data.materials.clear()
        obj.data.materials.append(material(name + ' fabric', color))
        return obj

    if role in ('dock_porter', 'boatman'):
        prefixes = ('lowerarm_', 'hand_') if role == 'dock_porter' else ('upperarm_', 'lowerarm_', 'hand_')
        keep = [v.index for v in outfit.data.vertices if arm_weight(v, outfit, prefixes) < (.12 if role == 'dock_porter' else .35)]
        mask(outfit, 'Short work sleeves' if role == 'dock_porter' else 'Sleeveless work tunic', keep)
        for name in ['Knee length wrapped dhoti', 'Dhoti woven border']:
            obj = bpy.data.objects[name]
            if role == 'boatman':
                for v in obj.data.vertices:
                    v.co.z = .53 + (v.co.z - .60) * (.31 / .24)
        # A soft overlapping sash has body-transferred weights through the waist.
        wrap = bpy.data.objects['Knee length wrapped dhoti']
        sash = wrap.copy()
        sash.data = wrap.data.copy()
        bpy.context.collection.objects.link(sash)
        sash.name = 'Wide madder waist sash' if role == 'dock_porter' else 'Narrow indigo waist binding'
        bottom = min(v.co.z for v in sash.data.vertices)
        top = max(v.co.z for v in sash.data.vertices)
        for v in sash.data.vertices:
            v.co.x *= 1.015
            v.co.y *= 1.02
            v.co.z = .81 + (v.co.z - bottom) / (top - bottom) * (.075 if role == 'dock_porter' else .045)
        sash.data.materials.clear()
        sash.data.materials.append(material(sash.name, (.30,.065,.04) if role == 'dock_porter' else (.035,.07,.13)))
        if role == 'dock_porter':
            # Fitted short work trousers replace the ring wrap that intersected
            # this muscular body's thighs. Reuse MPFB topology and skin weights.
            shorts = copy_garment('Porter fitted short work trousers', (.46,.39,.28))
            for modifier in list(shorts.modifiers):
                if modifier.type == 'MASK': shorts.modifiers.remove(modifier)
            lower_group = outfit.vertex_groups['Period lower only'].index
            lower = [v.index for v in shorts.data.vertices if v.co.z > .54
                     and any(g.group == lower_group and g.weight > .5 for g in v.groups)]
            mask(shorts, 'Short trouser legs', lower)
            for vertex in shorts.data.vertices: vertex.co += vertex.normal * .015
            import bmesh
            bm=bmesh.new();bm.from_mesh(shorts.data)
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                dist=.00001,plane_co=(0,0,.56),plane_no=(0,0,1),clear_inner=True)
            bm.to_mesh(shorts.data);bm.free()
            for name in ['Knee length wrapped dhoti', 'Dhoti woven border']:
                bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    else:
        # Recover fitted lower clothing from the same MPFB garment topology.
        trousers = copy_garment('Clerk full length trousers', (.13,.10,.075))
        for modifier in list(trousers.modifiers):
            if modifier.type == 'MASK':
                trousers.modifiers.remove(modifier)
        lower_group = outfit.vertex_groups['Period lower only'].index
        lower = [v.index for v in trousers.data.vertices
                 if any(g.group == lower_group and g.weight > .5 for g in v.groups)]
        mask(trousers, 'Fitted trousers component', lower)
        for v in trousers.data.vertices:
            v.co += v.normal * .009
        for name in ['Knee length wrapped dhoti', 'Dhoti woven border']:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
        vest = copy_garment('Clerk buttoned sleeveless waistcoat', (.095,.12,.14))
        keep = [v.index for v in vest.data.vertices
                if arm_weight(v, vest, ('upperarm_', 'lowerarm_', 'hand_')) < .35]
        mask(vest, 'Waistcoat armholes', keep)
        for v in vest.data.vertices:
            v.co += v.normal * .014
        # Small dull buttons follow the torso surface instead of floating boxes.
        points = [v.co for v in vest.data.vertices if v.index in keep]
        button_mat = material('Clerk horn buttons', (.30,.23,.14))
        for z in [1.02, 1.075, 1.13]:
            nearest = sorted(points, key=lambda p: p.x*p.x + (p.z-z)**2)[:18]
            y = min(p.y for p in nearest) - .006
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=.006, location=(0,y,z))
            button = bpy.context.object
            button.name = 'Waistcoat horn button'
            button.scale.y = .45
            button.data.materials.append(button_mat)
            bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
            group = button.vertex_groups.new(name='spine_01')
            group.add(list(range(len(button.data.vertices))), 1, 'REPLACE')
            button.parent = rig
            button.modifiers.new('Torso skin', 'ARMATURE').object = rig

    if body_surface is not None:
        # Fit actual cloth outside the unchanged complete body. Retain garment
        # topology/weights; do not hide or shrink body surfaces to clear outfits.
        from mathutils.bvhtree import BVHTree
        tree = BVHTree.FromPolygons([v.co for v in body_surface.vertices],
            [tuple(p.vertices) for p in body_surface.polygons])
        layers = {'Fitted cotton upper base': .012,
                  'Porter fitted short work trousers': .025,
                  'Clerk full length trousers': .025,
                  'Clerk buttoned sleeveless waistcoat': .030}
        for name, clearance in layers.items():
            obj = bpy.data.objects.get(name)
            if obj is None: continue
            for vertex in obj.data.vertices:
                point, normal, polygon, distance = tree.find_nearest(vertex.co)
                if point is not None and (vertex.co-point).dot(normal) < clearance:
                    vertex.co = point + normal * clearance
