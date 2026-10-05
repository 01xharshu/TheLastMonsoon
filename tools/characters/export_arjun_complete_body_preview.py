"""Separate preview export and source audit; does not replace playable Arjun."""
import bpy,sys,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from arjun_full_body import ensure_full_body
SOURCE=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_complete_body_fitted_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));audit=ensure_full_body()
body=bpy.data.objects['Arjun_MakeHuman_Body'];audit['enabled_body_masks']=[m.name for m in body.modifiers if m.type=='MASK' and (m.show_render or m.show_viewport)]
assert audit['enabled_body_masks']==['Hide helpers'],'Only helper exclusion may remain enabled'
foundation=bpy.data.objects['Arjun_Foundation_FittedShorts'];assert not foundation.hide_render
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
 if obj.type in ['MESH','ARMATURE'] and not obj.hide_render and obj.name!='Studio floor':obj.hide_set(False);obj.select_set(True)
bpy.context.view_layer.objects.active=body
OUT=ROOT/'WorkingAssets/Arjun/reference_fit/arjun_complete_body_preview.glb'
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_apply=True,export_skins=True,export_animations=False,export_morph=False)
blob=OUT.read_bytes();length,kind=struct.unpack_from('<II',blob,12);doc=json.loads(blob[20:20+length]);nodes={n.get('name'):n for n in doc['nodes']}
assert body.name in nodes and foundation.name in nodes
counts={}
for name in [body.name,foundation.name]:
 mesh=doc['meshes'][nodes[name]['mesh']];counts[name]=sum(doc['accessors'][p['attributes']['POSITION']]['count'] for p in mesh['primitives'])
 for primitive in mesh['primitives']:
  assert 'JOINTS_0' in primitive['attributes'],'Exported garment/body lacks skin weights'
  mat=doc.get('materials',[])[primitive['material']]
  if name==foundation.name:assert mat.get('alphaMode','OPAQUE')=='OPAQUE','Foundation must stay opaque'
triangles=sum((doc['accessors'][p['indices']]['count']//3 if 'indices' in p else doc['accessors'][p['attributes']['POSITION']]['count']//3) for mesh in doc['meshes'] for p in mesh['primitives'])
audit.update({'export_bytes':len(blob),'export_triangles':triangles,'mesh_count':len(doc['meshes']),'export':str(OUT.relative_to(ROOT)),'export_position_counts':counts,'foundation_exported_opaque':True,'status':'SOURCE_EXPORT_STRUCTURE_PASS_VISUAL_OPEN','runtime_replaced':False})
(ROOT/'docs/characters/arjun/reference_fit/current/full_body_export_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print('ARJUN_FULL_BODY_PREVIEW_EXPORT_PASS',counts,flush=True)
