"""Create an isolated street-person MPFB shape-fit candidate; never exports live assets.

The output is unapproved and must pass contact and rendered motion review.
"""
import bpy, json, sys
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
sex=args[args.index('--sex')+1] if '--sex' in args else 'female'
profile=int(args[args.index('--profile')+1]) if '--profile' in args else 5
source=int(args[args.index('--source')+1]) if '--source' in args else 1
if sex not in ('female','male') or not 1<=profile<=(6 if sex=='female' else 4) or not 1<=source<=4:raise ValueError('Invalid candidate or donor')
slug=f'{sex}_{source:02d}'
donor=ROOT/'WorkingAssets/NPCs/indian_street_variants'/slug/(slug+'.blend')
report=json.loads((donor.parent/'manifest.json').read_text());width=report['whole_character_width']
data=np.load(ROOT/'WorkingAssets/NPCs/indian_body_profiles'/f'{sex}_mpfb_deltas.npz')
delta=data[f'{sex}_{profile:02d}'].copy();delta[:,0]*=width
bpy.ops.wm.open_mainfile(filepath=str(donor));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if len(body.data.vertices)!=len(delta):raise RuntimeError('MPFB donor topology differs')
retain_complete_body(body)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
# Use complete, unmasked, unskinned donor surface for correspondence.
modifiers=[(m,m.show_viewport) for m in body.modifiers]
for m,_ in modifiers:
 if m.type in ('ARMATURE','MASK'):m.show_viewport=False
bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
group=body.vertex_groups['body'].index
human=[v.index for v in body.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)]
tree=KDTree(len(human))
for i in human:tree.insert(body.matrix_world@mesh.vertices[i].co,i)
tree.balance();ev.to_mesh_clear()
# Keep the same additive MPFB body profile beneath all clothing.
key=body.shape_key_add(name='Adult MPFB body profile',from_mix=False)
for i,v in enumerate(key.data):v.co+=Vector(delta[i])
key.value=1.0
# Transfer the same displacement to separate clothes as a first fitting pass.
# Subsequent geometric and visual checks decide whether this candidate is usable.
female_clothing=['Opaque fitted bra and thong foundation','Fitted cotton upper base','Woven sari pallu over blouse','Street coherent cotton blouse and pallu','Street sari back tail','Wrapped sari lower drape','Sari lower border']
male_clothing=['Street opaque foundation','Fitted cotton upper base','Bordered shoulder shawl','Street dhoti waist fold','Street folded dhoti l','Street folded dhoti r']
clothing=female_clothing if sex=='female' else male_clothing
counts={}
for name in clothing:
 obj=bpy.data.objects.get(name)
 if not obj:continue
 blocks=obj.data.shape_keys.key_blocks if obj.data.shape_keys else [None]
 for block in blocks:
  verts=block.data if block else obj.data.vertices
  inverse=obj.matrix_world.inverted();linear=inverse.to_3x3()@body.matrix_world.to_3x3()
  for vert in verts:
   _,index,_=tree.find(obj.matrix_world@vert.co)
   vert.co+=linear@Vector(delta[index])
 counts[name]=len(obj.data.vertices)
 obj.data.update()
for m,enabled in modifiers:m.show_viewport=enabled
retain_complete_body(body)
out=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/f'{sex}_{profile:02d}'
out.mkdir(parents=True,exist_ok=True)
body['body_profile']=f'{sex}_{profile:02d}'
body['approval']='unapproved candidate: garment fitting and animation review required'
bpy.ops.wm.save_as_mainfile(filepath=str(out/'candidate.blend'))
result={'sex':sex,'profile':profile,'source':str(donor.relative_to(ROOT)),'body_vertices':len(body.data.vertices),'garments':counts,'method':'MPFB body deltas; nearest complete body displacement transfer to clothing','visual_approved':False,'runtime_integrated':False}
(out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
print('INDIAN_BODY_CANDIDATE',json.dumps(result),flush=True)
