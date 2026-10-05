"""Individual adult identities, not a universal ethnicity or appearance model."""
from pathlib import Path
import json,struct

PROFILES = {
 'dock_porter': dict(age=.40, muscle=.92, weight=.48, height=.42),
 'boatman': dict(age=.56, muscle=.45, weight=.18, height=.42),
 'record_clerk': dict(age=.69, muscle=.18, weight=.90, height=.42),
}
TINTS = {'dock_porter':(.68,.47,.31,1), 'boatman':(.56,.38,.25,1), 'record_clerk':(.82,.64,.46,1)}
FACES = {
 'dock_porter': {'chin/chin-width-incr':.35, 'chin/chin-height-incr':.12, 'nose/nose-scale-depth-incr':.12, 'cheek/l-cheek-bones-incr':.20, 'cheek/r-cheek-bones-incr':.20},
 'boatman': {'chin/chin-width-decr':.32, 'head/head-scale-vert-incr':.16, 'head/head-fat-decr':.30, 'nose/nose-scale-horiz-decr':.18, 'nose/nose-scale-depth-incr':.26},
 'record_clerk': {'head/head-fat-incr':.50, 'chin/chin-height-decr':.20, 'cheek/l-cheek-volume-incr':.35, 'cheek/r-cheek-volume-incr':.35, 'nose/nose-scale-depth-decr':.14},
}

def apply_face(body, role):
 from bl_ext.blender_org.mpfb.services.targetservice import TargetService
 targets=Path.home()/'Library/Application Support/Blender/5.2/extensions/blender_org/mpfb/data/targets'
 for name,value in FACES[role].items():
  TargetService.load_target(body,str(targets/(name+'.target.gz')),weight=value)
 body['individual_face_targets']=json.dumps(FACES[role])

def tint_glb(path,role):
 raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+size])
 for material in doc.get('materials',[]):
  if material.get('name','').startswith('Warm brown skin'):
   material['pbrMetallicRoughness']['baseColorFactor']=TINTS[role]
 packed=json.dumps(doc,separators=(',',':')).encode();packed+=b' '*((-len(packed))%4)
 rest=raw[20+size:]
 path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(packed)+len(rest))+struct.pack('<I4s',len(packed),b'JSON')+packed+rest)
