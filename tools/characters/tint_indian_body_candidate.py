"""Tint packed candidate skin texture, leaving the source donor unchanged."""
import bpy, sys, numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
# Modest individual complexions; these values do not describe an ethnicity.
tints={'female_05':(1.30,1.20,1.12),'female_06':(.91,.95,.98),'male_02':(1.22,1.17,1.10)}
if slug not in tints:raise ValueError('No authored tone for '+slug)
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
if 'individual_skin_tint' in body:raise RuntimeError('Candidate is already tinted; rebuild it before changing the tint')
material=body.data.materials[0];bsdf=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
links=list(bsdf.inputs['Base Color'].links)
if len(links)!=1 or links[0].from_node.type!='TEX_IMAGE':raise RuntimeError('Unexpected skin texture graph')
node=links[0].from_node;old=node.image
pixels=np.empty(len(old.pixels),dtype=np.float32);old.pixels.foreach_get(pixels)
pixels.reshape((-1,4))[:,:3]=np.clip(pixels.reshape((-1,4))[:,:3]*np.array(tints[slug],dtype=np.float32),0,1)
image=bpy.data.images.new('Candidate '+slug+' skin',width=old.size[0],height=old.size[1],alpha=True)
image.colorspace_settings.name=old.colorspace_settings.name;image.pixels.foreach_set(pixels);image.pack();node.image=image
body['individual_skin_tint']=str(tints[slug]);bpy.ops.wm.save_as_mainfile(filepath=str(path))
print('INDIAN_CANDIDATE_SKIN',slug,tints[slug],'packed',image.packed_file is not None,flush=True)
