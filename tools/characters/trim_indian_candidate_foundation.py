"""Remove accidental arm-only faces from candidate foundation, preserving source."""
import bpy,bmesh,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Opaque fitted bra and thong foundation']
if bpy.data.objects.get('Untrimmed foundation source'):raise RuntimeError('Already trimmed')
source=obj.copy();source.data=obj.data.copy();source.name='Untrimmed foundation source';source['street_source_only']=True;source.hide_render=True;bpy.context.collection.objects.link(source);source.hide_set(True)
if obj.data.shape_keys:
 fitted=[v.co.copy() for v in obj.data.shape_keys.key_blocks['Basis'].data]
 obj.shape_key_clear()
 for vertex,coordinate in zip(obj.data.vertices,fitted):vertex.co=coordinate
groups={g.index for g in obj.vertex_groups if g.name.startswith(('upperarm_','lowerarm_','hand_','thumb_','index_','middle_','ring_','pinky_'))}
bm=bmesh.new();bm.from_mesh(obj.data);deform=bm.verts.layers.deform.active
if not deform:raise RuntimeError('Foundation weights missing')
faces=[face for face in bm.faces if all(sum(w for index,w in vertex[deform].items() if index in groups)>.80 for vertex in face.verts)]
if not faces:raise RuntimeError('No arm-only foundation faces detected')
count=len(faces);bmesh.ops.delete(bm,geom=faces,context='FACES');loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(obj.data);bm.free();obj.data.update();obj['fit_note']='Arm-only foundation faces removed; original retained source-only'
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('FOUNDATION_ARM_TRIM',slug,'faces',count,'remaining_vertices',len(obj.data.vertices),flush=True)
