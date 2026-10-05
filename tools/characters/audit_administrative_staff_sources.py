"""Read-only Blender audit; run runtime staff audit first. Do not save sources."""
import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
report=json.loads((root/'docs/world/administrative_staff_body_audit.json').read_text())
for asset in report['assets']:
 bpy.ops.wm.open_mainfile(filepath=str(root/asset['source']))
 bodies=[o for o in bpy.data.objects if o.type=='MESH' and ('makehuman_body' in o.name.lower() or o.name=='Official_MPFB_body')]
 assert len(bodies)==1,[(o.name,len(o.data.vertices)) for o in bodies]
 body=bodies[0]
 masks=[{'name':m.name,'viewport':m.show_viewport,'render':m.show_render} for m in body.modifiers if m.type=='MASK']
 assert all(not m['viewport'] and not m['render'] for m in masks if m['name']!='Hide helpers'),masks
 evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
 mesh=evaluated.to_mesh()
 count=len(mesh.vertices)
 evaluated.to_mesh_clear()
 assert count==13380,(asset['source'],body.name,count)
 print('SOURCE BODY',asset['source'],body.name,'raw',len(body.data.vertices),'evaluated',count,'masks',masks)
 asset['source_body']={'name':body.name,'evaluated_vertices':count,'mask_modifiers':masks}
(root/'docs/world/administrative_staff_body_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('ADMINISTRATIVE EDITABLE BODY AUDIT: PASS')
