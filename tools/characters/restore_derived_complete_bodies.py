"""Restore omitted donor body surface while preserving derived faces and outfits."""
import bpy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'))
donor=bpy.data.objects['village_farmer_MakeHuman_body'];rig=bpy.data.objects['village_farmer_rig'];rig.data.pose_position='REST'
for m in donor.modifiers:
 if m.type=='ARMATURE':m.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(donor.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
verts=[tuple(v.co) for v in mesh.vertices];faces=[tuple(p.vertices) for p in mesh.polygons]
weights=[[(donor.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in mesh.vertices]
uvs=[tuple(l.uv) for l in mesh.uv_layers.active.data]
report=[]
families=[sys.argv[sys.argv.index('--')+1]] if '--' in sys.argv else ['households','street_residents']
for family in families:
 for role in ([sys.argv[sys.argv.index('--')+2]] if '--' in sys.argv else ['landowner','merchant']):
  path=ROOT/f'WorkingAssets/NPCs/{family}/{role}/{role}.blend';bpy.ops.wm.open_mainfile(filepath=str(path))
  body=bpy.data.objects['village_farmer_MakeHuman_body'];old=body.data
  table={}
  for poly in old.polygons:
   for li in poly.loop_indices:
    uv=old.uv_layers.active.data[li].uv;vi=old.loops[li].vertex_index
    table.setdefault(tuple(round(x,6) for x in uv),set()).add(vi)
  new=bpy.data.meshes.new('Complete original MPFB body with retained derived identity');new.from_pydata(verts,[],faces);new.update()
  layer=new.uv_layers.new(name=old.uv_layers.active.name);matched=set()
  for i,uv in enumerate(uvs):
   layer.data[i].uv=uv;vi=new.loops[i].vertex_index
   candidates=table.get(tuple(round(x,6) for x in uv),set())
   if candidates:
    closest=min(candidates,key=lambda j:(old.vertices[j].co-new.vertices[vi].co).length_squared)
    if (old.vertices[closest].co-new.vertices[vi].co).length<.06:
     new.vertices[vi].co=old.vertices[closest].co;matched.add(closest)
  assert len(matched)/len(old.vertices)>.98,(family,role,len(matched),len(old.vertices))
  for mat in old.materials:new.materials.append(mat)
  for poly in new.polygons:poly.use_smooth=True
  body.data=new
  for i,assignments in enumerate(weights):
   for name,weight in assignments:(body.vertex_groups.get(name) or body.vertex_groups.new(name=name)).add([i],weight,'REPLACE')
  body['complete_runtime_body']=True;body['restoration']='Original MPFB donor topology; existing UV-corresponding derived body coordinates preserved'
  bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
  bpy.ops.export_scene.gltf(filepath=str(ROOT/f'characters/npcs/{family}/{role}.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
  report.append({'source':str(path.relative_to(ROOT)),'preserved_original_vertices':len(matched),'previous_vertices':len(old.vertices),'complete_vertices':len(new.vertices)})
report_path=ROOT/'docs/characters/npcs/whole_body_derived_restoration.json'
previous=json.loads(report_path.read_text()) if report_path.exists() else []
updated={r['source']:r for r in previous+report}
report_path.write_text(json.dumps(list(updated.values()),indent=2)+'\n')
