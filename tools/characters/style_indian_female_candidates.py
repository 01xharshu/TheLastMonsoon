"""Give two isolated adult candidates distinct woven cloth palettes."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
styles={
 'female_05': {'old_blouse':(.30,.25,.11),'old_wrap':(.31,.115,.105),'blouse':(.32,.22,.13),'wrap':(.14,.25,.17)},
 'female_06': {'old_blouse':(.42,.32,.22),'old_wrap':(.12,.19,.29),'blouse':(.38,.28,.19),'wrap':(.33,.12,.18)},
}
if slug not in styles:raise ValueError('Unsupported candidate palette')
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
cloth=bpy.data.objects['Street coherent cotton blouse and pallu'];spec=styles[slug]
if cloth.get('individual_palette'):raise RuntimeError('Candidate palette already applied')
attr=cloth.data.color_attributes.get('StreetCotton')
if attr is None:raise RuntimeError('Expected editable fabric colors missing')
a=Vector(spec['old_blouse']);b=Vector(spec['old_wrap']);direction=b-a;denom=direction.length_squared
for entry in attr.data:
 old=Vector(entry.color[:3]);t=max(0,min(1,(old-a).dot(direction)/denom));new=Vector(spec['blouse']).lerp(Vector(spec['wrap']),t);entry.color=(*new,entry.color[3])
for mat in bpy.data.materials:
 if mat.name.startswith('River plain woven cotton'):
  color=(*spec['wrap'],1);mat.diffuse_color=color
  if mat.use_nodes:
   node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');node.inputs['Base Color'].default_value=color
cloth['individual_palette']=slug+' muted woven cotton';bpy.ops.wm.save_as_mainfile(filepath=str(path));print('FEMALE_CLOTH_PALETTE',slug,spec['wrap'],flush=True)
