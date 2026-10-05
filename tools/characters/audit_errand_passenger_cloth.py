import bpy,json,sys
from pathlib import Path
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/errand_passenger/errand_passenger_mpfb.blend'))
rig=bpy.data.objects['village_farmer_rig'];body=bpy.data.objects['village_farmer_MakeHuman_body'];rig.data.pose_position='POSE';rig.animation_data.action=None
base={p.name:p.rotation_quaternion.copy() for p in rig.pose.bones}
result=[]
for amount in [0,.25,.5,.75,1]:
 for side in ['l','r']:
  for prefix,angle in [('thigh_',-1.5),('calf_',1.5)]:
   bone=rig.pose.bones[prefix+side];axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
   bone.rotation_quaternion=base[bone.name]@Quaternion(axis,angle*amount)
 for name in ['Kurta loose lower panel','Knee length wrapped dhoti','Dhoti woven border']:
  bpy.data.objects[name].data.shape_keys.key_blocks['PassengerSeatedClearance'].value=amount
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();skin=body.evaluated_get(deps)
 bvh=BVHTree.FromPolygons([skin.matrix_world@v.co for v in skin.data.vertices],[list(p.vertices) for p in skin.data.polygons])
 for name in ['Kurta loose lower panel','Knee length wrapped dhoti','Dhoti woven border']:
  cloth=bpy.data.objects[name].evaluated_get(deps);samples=[cloth.matrix_world@v.co for v in cloth.data.vertices]+[cloth.matrix_world@p.center for p in cloth.data.polygons]
  signed=[]
  for point in samples:
   near,normal,_,_=bvh.find_nearest(point);signed.append((point-near).dot(normal))
  result.append({'amount':amount,'garment':name,'samples':len(samples),'inside_samples':sum(v<-.002 for v in signed),'max_penetration_m':max(0,-min(signed))})
report={'complete_body_vertices':len(body.data.vertices),'body_masks':[m.name for m in body.modifiers if m.type=='MASK'],'foundation_vertices':len(bpy.data.objects['Opaque adult foundation shorts'].data.vertices),'samples':result}
(ROOT/'WorkingAssets/NPCs/errand_passenger/clearance_audit.json').write_text(json.dumps(report,indent=2)+'\n');print('CLOTH_CLEARANCE',json.dumps(report))
