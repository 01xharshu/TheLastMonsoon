"""Inspect actual editable MPFB geometry; measurements do not grant art approval."""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
report={'scope':'actual rest body slices and foundation isolation; no visual or motion approval','actors':{},'errors':[]}
for role in ['dock_porter','boatman','record_clerk']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'WorkingAssets/NPCs/{role}/{role}_mpfb.blend'))
 body=bpy.data.objects[role+'_MakeHuman_body'];rig=bpy.data.objects[role+'_rig'];rig.data.pose_position='REST'
 if any(m.show_viewport or m.show_render for m in body.modifiers if m.type=='MASK' and m.name!='Hide helpers'):
  report['errors'].append(role+': covered-body masking still enabled')
 for modifier in body.modifiers:
  if modifier.type=='MASK' and modifier.name!='Hide helpers':modifier.show_viewport=False
 bpy.context.view_layer.update()
 ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 names={group.index:group.name for group in body.vertex_groups}
 points=[v.co for v in mesh.vertices if sum(g.weight for g in v.groups if names[g.group] in ['pelvis','spine_01','spine_02','spine_03'])>.65]
 height=max(v.co.z for v in mesh.vertices)-min(v.co.z for v in mesh.vertices)
 torso={}
 for label,z in [('waist',rig.data.bones['pelvis'].head_local.z+.10),('chest',rig.data.bones['spine_03'].head_local.z-.04)]:
  section=[point for point in points if abs(point.z-z)<.025]
  torso[label]={'width_m':max(v.x for v in section)-min(v.x for v in section),'depth_m':max(v.y for v in section)-min(v.y for v in section)}
 ev.to_mesh_clear()
 foundation=bpy.data.objects['Opaque fitted underwear foundation']
 forbidden={g.index for g in foundation.vertex_groups if g.name.startswith(('hand_','lowerarm_','upperarm_','index_','middle_','thumb_','ring_','pinky_'))}
 arm_vertices=sum(1 for v in foundation.data.vertices if sum(g.weight for g in v.groups if g.group in forbidden)>.20)
 if arm_vertices:report['errors'].append(role+': foundation includes arm/hand vertices')
 report['actors'][role]={'rest_height_m':height,'torso':torso,'foundation_arm_vertices':arm_vertices,'body_vertices':len(body.data.vertices),'face_targets':json.loads(body['individual_face_targets'])}
lean=report['actors']['boatman'];heavy=report['actors']['record_clerk']
if heavy['torso']['waist']['depth_m']/heavy['rest_height_m'] <= lean['torso']['waist']['depth_m']/lean['rest_height_m']*1.15:
 report['errors'].append('Heavy body waist-depth distinction is insufficient')
report['passed']=not report['errors']
(ROOT/'docs/characters/npcs/purpose_body_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('PURPOSE_BODY_AUDIT',json.dumps(report),flush=True)
if report['errors']:raise RuntimeError(report['errors'])
