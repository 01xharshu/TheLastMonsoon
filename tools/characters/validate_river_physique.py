"""Verify complete canonical donor physique, not merely matching topology."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
body=bpy.data.objects['village_woman_MakeHuman_body']
before=set(bpy.data.objects)
with bpy.data.libraries.load(str(ROOT/'WorkingAssets/NPCs/village_woman/village_woman_motion_candidate.blend'),link=False) as (_,loaded):loaded.objects=[body.name]
donor=loaded.objects[0]
temporary=bpy.data.collections.new('Temporary canonical donor');bpy.context.scene.collection.children.link(temporary)
for obj in set(bpy.data.objects)-before:temporary.objects.link(obj)
values={key.name:key.value for key in donor.data.shape_keys.key_blocks}
if any(abs(body.data.shape_keys.key_blocks[name].value-value)>1e-7 for name,value in values.items()):raise RuntimeError('Canonical physique targets changed')
def points(obj):
    obj.parent.animation_data_clear();obj.parent.data.pose_position='REST'
    for modifier in obj.modifiers:
        if modifier.type=='MASK':modifier.show_viewport=False
    for key in obj.data.shape_keys.key_blocks:
        if key.name.startswith('River identity'):key.value=0
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    try:return [ev.matrix_world@vertex.co for vertex in mesh.vertices]
    finally:ev.to_mesh_clear()
actual=points(body);expected=points(donor)
if len(actual)!=len(expected):raise RuntimeError('Complete donor topology changed')
maximum=max((a-b).length for a,b in zip(actual,expected))
if maximum>.00001:raise RuntimeError('Canonical body geometry changed: '+str(maximum))
print('RIVER_CANONICAL_PHYSIQUE PASS targets='+str(len(values))+' vertices='+str(len(actual))+' maximum_gap_m='+str(maximum),flush=True)
