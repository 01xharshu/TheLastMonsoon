"""Export one isolated candidate to a non-production Godot asset for review."""
import bpy,sys,struct,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
source=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
output=Path(args[args.index('--output')+1]).expanduser().resolve() if '--output' in args else ROOT/'characters/npcs/indian_body_candidates'/(slug+'.glb')
if '--source' in args and '--output' not in args:raise ValueError('A study source requires a separate explicit output')
if output.suffix.lower()!='.glb':raise ValueError('Output must be a GLB')
if '--source' in args and output.exists():raise ValueError('Study export requires a new output')
bpy.ops.wm.open_mainfile(filepath=str(source))
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if '--source' in args and body.get('body_profile')!=slug:raise ValueError('Study body identity does not match requested export')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST';retain_complete_body(body)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
cutout=bpy.data.objects.new(body.name+'_export_cutout',mesh);bpy.context.collection.objects.link(cutout)
for group in body.vertex_groups:cutout.vertex_groups.new(name=group.name)
cutout.parent=rig;cutout.matrix_parent_inverse=body.matrix_parent_inverse.copy();cutout.matrix_basis=body.matrix_basis.copy()
cutout.modifiers.new('Original MPFB rig','ARMATURE').object=rig
for name in ('body_profile','fuller_profile','street_arm_clearance_rad','street_fit_body_waist','street_body_fit_version','adult_character','adult_secondary_version','adult_secondary_breast_mass','adult_secondary_rear_mass'):
 if name in body:cutout[name]=body[name]
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj!=body and not obj.get('street_source_only',False):obj.select_set(True)
bpy.context.view_layer.objects.active=rig
path=output;path.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_all_influences=True,export_cameras=False,export_lights=False,export_morph=False,export_extras=True)
raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);names={n.get('name') for n in doc['nodes'] if 'mesh' in n}
if not any('MakeHuman_body_export_cutout' in n for n in names):raise RuntimeError('Complete body missing')
print('INDIAN_CANDIDATE_EXPORT',slug,'source_body_vertices',len(body.data.vertices),'runtime_nodes',len(names),'path',str(path),flush=True)
