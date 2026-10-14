"""Keep the original MPFB physique; clothing must never reset its macro keys."""
import bpy

def restore_donor_physique(root,body):
    donor=root/'WorkingAssets/NPCs/village_woman/village_woman_motion_candidate.blend'
    previous_objects=set(bpy.data.objects)
    with bpy.data.libraries.load(str(donor),link=False) as (available,loaded):
        if body.name not in available.objects:raise RuntimeError('Original MPFB donor body missing')
        loaded.objects=[body.name]
    original=loaded.objects[0];mesh=original.data
    try:
        values={key.name:key.value for key in original.data.shape_keys.key_blocks if not key.name.startswith('River identity')}
        missing=set(values)-set(body.data.shape_keys.key_blocks.keys())
        if missing:raise RuntimeError('Canonical MPFB physique keys missing: '+str(sorted(missing)))
        changed=0
        for name,value in values.items():
            key=body.data.shape_keys.key_blocks[name]
            if abs(key.value-value)>1e-7:changed+=1
            key.value=value
        bpy.context.view_layer.update()
        print('RIVER_CANONICAL_PHYSIQUE keys='+str(len(values))+' restored='+str(changed),flush=True)
        return values
    finally:
        added=set(bpy.data.objects)-previous_objects
        armatures={obj.data for obj in added if obj.type=='ARMATURE'}
        for obj in added:bpy.data.objects.remove(obj,do_unlink=True)
        if mesh.users==0:bpy.data.meshes.remove(mesh)
        for armature in armatures:
            if armature.users==0:bpy.data.armatures.remove(armature)
