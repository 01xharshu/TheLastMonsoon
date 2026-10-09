"""Refine an existing sampled river source after its continuous leg envelope."""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from river_coherent_cloth import fit_key
from river_asset_export import export_river_asset
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
data=json.loads((ROOT/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inv=c.inverted()
corrections={n:(c@Matrix(rest)@inv).inverted()@rig.data.bones[n].matrix_local for n,rest in data['rest'].items() if n in rig.data.bones}
rig.animation_data_clear();rig.data.pose_position='POSE'
objects=[bpy.data.objects[n] for n in ['Fitted cotton upper base','Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']]
for obj in objects:
 for key in obj.data.shape_keys.key_blocks:key.value=0
for sample,pose in enumerate(data['poses']):
 apply_river_pose(rig,pose['bones'],c,corrections)
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
 tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
 for obj in objects:
  key=obj.data.shape_keys.key_blocks[pose['key']];key.value=1
  fit_key(rig,obj,tree,key,reset_key=False);key.value=0
 if sample%24==0:print('RIVER_CONTACT_REFINEMENT',sample,flush=True)
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
rig.data.pose_position='REST'
export_river_asset(ROOT,rig,body,894)
