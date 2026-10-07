"""Distinct fitted work-clothing studies over the unchanged MPFB bodies."""
import bpy
from mathutils import Vector


def continuous_arm_cut(obj, prefixes, limit):
    """Cut fabric along interpolated deform-weight contours, not whole faces."""
    import bmesh
    bm=bmesh.new();bm.from_mesh(obj.data)
    deform=bm.verts.layers.deform.verify()
    indices={g.index for g in obj.vertex_groups if g.name.startswith(prefixes)}
    upper=obj.vertex_groups['Period upper only'].index
    discard=[f for f in bm.faces if any(v[deform].get(upper,0)<.5 for v in f.verts)]
    bmesh.ops.delete(bm,geom=discard,context='FACES')
    def value(v):return sum(v[deform].get(i,0) for i in indices)
    cuts=set()
    for edge in list(bm.edges):
        a,b=edge.verts;wa,wb=value(a),value(b)
        if (wa-limit)*(wb-limit)<0:
            t=(limit-wa)/(wb-wa);weights_a=dict(a[deform]);weights_b=dict(b[deform])
            _,v=bmesh.utils.edge_split(edge,a,t)
            for index in weights_a.keys()|weights_b.keys():v[deform][index]=(1-t)*weights_a.get(index,0)+t*weights_b.get(index,0)
            cuts.add(v)
    for face in list(bm.faces):
        boundary=[v for v in face.verts if v in cuts]
        if len(boundary)==2 and len(face.verts)>3:
            bmesh.utils.face_split(face,boundary[0],boundary[1])
    discard=[f for f in bm.faces if sum(value(v) for v in f.verts)/len(f.verts)>limit+1e-6]
    bmesh.ops.delete(bm,geom=discard,context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    lowest=min(v.co.z for v in bm.verts)
    for v in bm.verts:
        if v.is_boundary and v.co.z<lowest+.07:v.co.z=lowest+.015
    bm.to_mesh(obj.data);bm.free()
    for modifier in list(obj.modifiers):
        if modifier.type=='MASK':obj.modifiers.remove(modifier)
    obj['armhole_construction']='Continuous interpolated fabric contour; original cloth weights retained'


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
        base=bpy.data.objects.get('Purpose garment donor') or outfit
        obj = base.copy()
        obj.data = base.data.copy()
        bpy.context.collection.objects.link(obj)
        obj.name = name
        obj.data.materials.clear()
        obj.data.materials.append(material(name + ' fabric', color))
        return obj

    if role in ('dock_porter', 'boatman'):
        prefixes = ('lowerarm_', 'hand_') if role == 'dock_porter' else ('upperarm_', 'lowerarm_', 'hand_')
        keep = [v.index for v in outfit.data.vertices if arm_weight(v, outfit, prefixes) < (.12 if role == 'dock_porter' else .35)]
        # Keep an unchanged donor for the trousers before trimming upper cloth.
        donor=outfit.copy();donor.data=outfit.data.copy()
        bpy.context.collection.objects.link(donor);donor.name='Purpose garment donor'
        continuous_arm_cut(outfit,prefixes,.12 if role=='dock_porter' else .35)
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
            v.co.z = min(p.co.z for p in outfit.data.vertices) - .025 + (v.co.z - bottom) / (top - bottom) * (.065 if role == 'dock_porter' else .045)
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
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                dist=.00001,plane_co=(0,0,min(v.co.z for v in outfit.data.vertices)+.04),plane_no=(0,0,1),clear_outer=True)
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
        continuous_arm_cut(vest,('upperarm_', 'lowerarm_', 'hand_'),.35)
        for v in vest.data.vertices:
            v.co += v.normal * .014
        # Small dull buttons follow the torso surface instead of floating boxes.
        points = [v.co for v in vest.data.vertices]
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
        layers = {'Fitted cotton upper base': .024,
                  'Porter fitted short work trousers': .038,
                  'Clerk full length trousers': .038,
                  'Clerk buttoned sleeveless waistcoat': .044}
        for name in ['Wide madder waist sash','Narrow indigo waist binding']:
            obj=bpy.data.objects.get(name)
            if obj:
                for v in obj.data.vertices:
                    point,normal,_,distance=tree.find_nearest(v.co)
                    if point is not None:v.co=point+normal*.052
        for name, clearance in layers.items():
            obj = bpy.data.objects.get(name)
            if obj is None: continue
            for vertex in obj.data.vertices:
                point, normal, polygon, distance = tree.find_nearest(vertex.co)
                if point is not None and (vertex.co-point).dot(normal) < clearance:
                    vertex.co = point + normal * clearance

    donor=bpy.data.objects.get('Purpose garment donor')
    if donor:bpy.data.objects.remove(donor,do_unlink=True)

    for name in ['Fitted cotton upper base','Knee length wrapped dhoti','Dhoti woven border',
                 'Wide madder waist sash','Narrow indigo waist binding',
                 'Porter fitted short work trousers','Clerk full length trousers','Clerk buttoned sleeveless waistcoat']:
        obj=bpy.data.objects.get(name)
        if obj:
            edge=obj.modifiers.new('Fabric thickness and finished edge','SOLIDIFY')
            edge.thickness=.002;edge.offset=-1.0
