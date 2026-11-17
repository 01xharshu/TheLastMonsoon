"""Update the fitted editable study and export without moving any vertex."""
import bpy,json,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from fabric_uvs import ensure_fabric_uvs
folder=ROOT/'WorkingAssets/NPCs/river_activity';source=folder/'river_activity.blend'
if (folder/'fit_checkpoint.json').exists():raise RuntimeError('Finish pose fitting first')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
before={o.name:[tuple(v.co) for v in o.data.vertices] for o in bpy.data.objects if o.type=='MESH'}
updated=[]
for obj in bpy.data.objects:
    if obj.type=='MESH' and ensure_fabric_uvs(obj):updated.append(obj.name)
for obj in bpy.data.objects:
    if obj.name in before:assert before[obj.name]==[tuple(v.co) for v in obj.data.vertices]
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type=='MESH' and not obj.get('activity_source_only',False):obj.select_set(True)
rig.data.pose_position='POSE';rig.animation_data_create();rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1)
runtime=ROOT/'characters/npcs/activity_people/river_activity.glb'
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_all_influences=True,export_apply=False,export_morph_normal=False,export_morph_tangent=False,export_vertex_color='ACTIVE')
report=json.loads((folder/'manifest.json').read_text());report.update(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),fabric_uvs=True)
(folder/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('RIVER_FABRIC_UVS',json.dumps({'updated':updated,'geometry_unchanged':True}),flush=True)
