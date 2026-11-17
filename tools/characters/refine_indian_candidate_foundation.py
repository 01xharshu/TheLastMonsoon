"""Refine candidate foundation cut; retain the full body and prior garment."""
import bpy,bmesh,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from street_female_garments import smooth_hems
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Opaque fitted bra and thong foundation']
if bpy.data.objects.get('Retained pre-cut foundation'):raise RuntimeError('Already refined')
backup=obj.copy();backup.data=obj.data.copy();backup.name='Retained pre-cut foundation';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
if obj.data.shape_keys:
 fitted=[v.co.copy() for v in obj.data.shape_keys.key_blocks['Basis'].data];obj.shape_key_clear()
 for vertex,coordinate in zip(obj.data.vertices,fitted):vertex.co=coordinate
bm=bmesh.new();bm.from_mesh(obj.data)
def remove_face(face):
 p=obj.matrix_world@face.calc_center_median();t=max(0,min(1,(p.z-.64)/.155));width=.025+.035*t
 return .64<p.z<.795 and p.y>=-.025 and abs(p.x)>width
remove=[face for face in bm.faces if remove_face(face)]
if not remove:raise RuntimeError('Expected rear panel not found')
bmesh.ops.delete(bm,geom=remove,context='FACES');loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(obj.data);bm.free();obj.data.update();smooth_hems(obj)
obj['construction']='Opaque body-fitted foundation with narrow rear panel; previous version retained source-only'
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('FOUNDATION_CUT_REFINED',slug,'removed_faces',len(remove),flush=True)
