"""Fit retained upper garments to native work poses without changing MPFB anatomy.

Input poses and build logs belong in the caller's temporary directory. Successful
fits retain the authored pose inputs beside the editable source for rebuilding.
"""
import bpy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
from river_surface_binding import bind_surface
from river_cloth_correctives import fit_river_cloth
from river_asset_export import export_river_asset
pose_path=Path(sys.argv[sys.argv.index('--')+1])
data=json.loads(pose_path.read_text())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
retain_complete_body(body);rig.data.pose_position='REST';rig.animation_data_clear()
mask_state=[(m,m.show_viewport) for m in body.modifiers if m.type=='MASK']
for m,_ in mask_state:m.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(a.group==group and a.weight>.5 for a in v.groups)}
objects=[bpy.data.objects[name] for name in ['Fitted cotton upper base','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']]
for obj in objects:
 if obj.data.shape_keys:obj.shape_key_clear()
 bind_surface(obj,body,mesh,human)
bpy.data.meshes.remove(mesh)
for m,enabled in mask_state:m.show_viewport=enabled
fit_river_cloth(ROOT,rig,body,objects,pose_data=data)
# Export first: a fitting/export failure must leave the live timeline intact.
export_river_asset(ROOT,rig,body,len(objects[-1].data.polygons))
# Runtime and source use the same bounded timeline. Lower fabric stays under
# its existing joint-envelope controller and never needs hundreds of morphs.
(ROOT/'characters/npcs/indian/river_cloth_timeline.gd').write_text('extends RefCounted\n## Authored upper-clothing contact poses; calmer phases stay sparse.\nconst TIMES := '+json.dumps(data['times'])+'\n')
(ROOT/'WorkingAssets/NPCs/river_woman/poses.json').write_text(json.dumps(data)+'\n')
