"""Small facial identities on the retained adult MPFB body, without recutting it."""
import bpy,math
from mathutils import Vector

PROFILES=[(.10,.035,-.002),(-.075,-.045,.004)]

def facial_offset(point,head,profile):
    jaw,cheek,nose=profile
    low=math.exp(-((point.z-(head-.035))/.030)**2)
    mid=math.exp(-((point.z-(head+.025))/.020)**2)
    front=max(0,min(1,(-point.y-.025)/.05))
    return Vector((point.x*(jaw*low+cheek*mid),-nose*math.exp(-(point.x/.025)**2)*front*mid,0)) if point.z>head-.09 else Vector()

def retain_source_shapes(rig,body):
    masks=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
    for modifier,_ in masks:modifier.show_viewport=False
    bpy.context.view_layer.update()
    ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    try:
        head=(rig.matrix_world@rig.data.bones['head'].head_local).z
        inverse=body.matrix_world.to_3x3().inverted()
        group=body.vertex_groups['body'].index
        human={vertex.index for vertex in body.data.vertices if any(value.group==group and value.weight>.5 for value in vertex.groups)}
        basis=body.data.shape_keys.key_blocks['Basis']
        for identity,profile in enumerate(PROFILES,1):
            name='River identity %d'%identity
            key=body.data.shape_keys.key_blocks.get(name) or body.shape_key_add(name=name)
            key.value=0
            for index,vertex in enumerate(key.data):
                delta=facial_offset(body.matrix_world@mesh.vertices[index].co,head,profile) if index in human else Vector()
                vertex.co=basis.data[index].co+inverse@delta
    finally:
        ev.to_mesh_clear()
        for modifier,enabled in masks:modifier.show_viewport=enabled

def add_export_shapes(rig,cutout):
    head=(rig.matrix_world@rig.data.bones['head'].head_local).z
    inverse=cutout.matrix_world.to_3x3().inverted()
    basis=cutout.shape_key_add(name='Basis')
    for identity,profile in enumerate(PROFILES,1):
        key=cutout.shape_key_add(name='River identity %d'%identity)
        for vertex,original in zip(key.data,basis.data):
            vertex.co=original.co+inverse@facial_offset(cutout.matrix_world@original.co,head,profile)
