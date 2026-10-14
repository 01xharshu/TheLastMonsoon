"""Verify authoring skin-transform caching against the original arithmetic."""
import bpy,json,sys,os
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from river_surface_binding import inverse_skin
from river_cloth_correctives import apply_river_pose
bpy.ops.wm.open_mainfile(filepath=os.environ.get('TLM_RIVER_SOURCE_OVERRIDE',str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend')))
rig=bpy.data.objects['village_woman_rig'];obj=bpy.data.objects['Fitted cotton upper base']
rig.animation_data_clear();rig.data.pose_position='POSE'
data=json.loads((ROOT/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inv=c.inverted()
corrections={name:(c@Matrix(rest)@inv).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
maximum=0.0;checked=0
for sample in [0,257,500]:
    apply_river_pose(rig,data['poses'][sample]['bones'],c,corrections)
    cached=inverse_skin(rig,obj)
    selected=sorted({round(index*(len(obj.data.vertices)-1)/63) for index in range(64)})
    for index in selected:
        vertex=obj.data.vertices[index];actual=cached[index]
        matrix=Matrix.Identity(4)*0;total=0
        for assignment in vertex.groups:
            bone=rig.pose.bones.get(obj.vertex_groups[assignment.group].name)
            if bone:matrix+=(bone.matrix@bone.bone.matrix_local.inverted())*assignment.weight;total+=assignment.weight
        expected=(rig.matrix_world@(matrix*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world).inverted_safe()
        gap=max(abs(actual[row][column]-expected[row][column]) for row in range(4) for column in range(4))
        maximum=max(maximum,gap);checked+=1
if maximum>1e-6:raise RuntimeError('Skin cache changes arithmetic: '+str(maximum))
print('RIVER_SKIN_CACHE PASS poses=3 matrices='+str(checked)+' maximum_gap='+str(maximum),flush=True)
