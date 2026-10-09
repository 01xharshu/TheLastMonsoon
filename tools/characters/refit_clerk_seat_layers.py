"""Fit the existing seat waistcoat outside its cotton shirt, retaining the body."""
import bpy,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_gait import normalize_animation_times
source=Path(sys.argv[sys.argv.index('--source')+1]) if '--source' in sys.argv else ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
shirt=bpy.data.objects['Fitted cotton upper base'];vest=bpy.data.objects['Clerk buttoned sleeveless waistcoat']
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
if '--export-only' not in sys.argv:
 from purpose_seat_layers import fit_outer_waistcoat
 fit_outer_waistcoat(rig,body,shirt,vest)
 bpy.context.scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(source))
# Bake the helper-excluded skin with all human surfaces intact.
# The editable source retains its complete MPFB body and all foundation layers.
# The stationary runtime actor uses only seat correctives. Keep walk keys in
# the saved editable source, but avoid loading their unused GPU payload here.
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in list(obj.data.shape_keys.key_blocks):
   if key.name.startswith('Walk cloth '):obj.shape_key_remove(key)
rig.data.pose_position='REST';bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
skin=bpy.data.objects.new('record_clerk_export_full_body',mesh);bpy.context.collection.objects.link(skin)
for group in body.vertex_groups:skin.vertex_groups.new(name=group.name)
skin.parent=rig;skin.matrix_parent_inverse=body.matrix_parent_inverse.copy();skin.matrix_basis=body.matrix_basis.copy()
skin.modifiers.new('Complete skin','ARMATURE').object=rig
rig.data.pose_position='POSE';bpy.context.scene.frame_set(1);bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj!=body:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=Path(sys.argv[sys.argv.index('--runtime')+1]) if '--runtime' in sys.argv else ROOT/'characters/npcs/review/record_clerk_seat.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_all_influences=True,export_apply=False)
normalize_animation_times(runtime)
subprocess.run(['/usr/bin/python3',str(ROOT/'tools/characters/audit_clerk_seat_body.py'),'--candidate',str(runtime)],check=True)
