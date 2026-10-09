"""Bake body-derived waist seam bindings; runtime must not read GPU mesh buffers."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
profiles={}
for role,path,name in [('merchant','households/merchant/merchant.blend','village_farmer_MakeHuman_body'),('landowner','households/landowner/landowner.blend','village_farmer_MakeHuman_body'),('official_woman','british/official_pair/official_pair_mpfb_candidate.blend','Companion_MPFB_body')]:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs'/path))
 body=bpy.data.objects[name];rig=next(m.object for m in body.modifiers if m.type=='ARMATURE');rig.data.pose_position='REST'
 bpy.context.view_layer.update();mesh=body.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
 hip=rig.data.bones['pelvis'].head_local;to_rig=rig.matrix_world.inverted()@body.matrix_world
 torso={g.index for g in body.vertex_groups if g.name=='pelvis' or g.name.startswith('spine_')}
 samples=[]
 for vertex in mesh.vertices:
  at=to_rig@vertex.co
  if sum(g.weight for g in vertex.groups if g.group in torso)>.65 and abs(at.z-hip.z-.12)<.024:samples.append(at)
 assert len(samples)>32,(role,len(samples))
 bindings=[]
 for side in range(32):
  angle=math.tau*side/32;radial=Vector((math.cos(angle),math.sin(angle),0));radius=0
  for at in samples:
   delta=at-hip;delta.z=0
   if delta.length>.01 and delta.normalized().dot(radial)>.99:radius=max(radius,delta.dot(radial))
  assert radius>.05,(role,side,radius)
  point=hip+Vector((0,0,.12))+radial*(radius+.014)
  local=rig.data.bones['pelvis'].matrix_local.inverted()@point
  bindings.append([local.x,local.z,-local.y])
 profiles[role]={'source':str(path),'body_samples':len(samples),'clearance_m':.014,'bindings':bindings}
(ROOT/'characters/npcs/households/waist_profiles.tres').write_text('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/schema = 1\nmetadata/profiles = '+json.dumps(profiles,indent=1)+'\n')
print('WAIST_PROFILES_BAKED',{role:p['body_samples'] for role,p in profiles.items()})
