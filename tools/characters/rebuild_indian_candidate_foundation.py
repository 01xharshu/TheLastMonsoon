"""Build higher-resolution opaque foundation from the retained MPFB surface."""
import bpy,bmesh,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
for m in body.modifiers:
 if m.type=='MASK':m.show_viewport=False
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
source=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
bm=bmesh.new();bm.from_mesh(source);deform=bm.verts.layers.deform.active
if deform is None:raise RuntimeError('Missing MPFB body skin weights')
core=body.vertex_groups['body'].index
arms={g.index for g in body.vertex_groups if g.name.startswith(('upperarm_','lowerarm_','hand_','thumb_','index_','middle_','ring_','pinky_'))}
# Refine only regions near either garment. Interpolated MPFB bone weights
# preserve body attachment and give the fabric a smoother cut boundary.
candidates=[f for f in bm.faces if any((.61<(body.matrix_world@v.co).z<.86 or .98<(body.matrix_world@v.co).z<1.25) and v[deform].get(core,0)>.5 for v in f.verts)]
edges=list({e for f in candidates for e in f.edges})
bmesh.ops.subdivide_edges(bm,edges=edges,cuts=2,use_grid_fill=True)
def covered(v):
 p=body.matrix_world@v.co
 if v[deform].get(core,0)<.5 or sum(v[deform].get(i,0) for i in arms)>.15:return False
 top=1.005<p.z<1.17 or (1.15<p.z<1.225 and .095<abs(p.x)<.145)
 band=.795<p.z<.835
 t=max(0,min(1,(p.z-.64)/.155))
 front_width=.030+.12*t;back_width=.025+.11*t
 bottom=.64<p.z<.80 and ((p.y<-.025 and abs(p.x)<front_width) or (p.y>=-.025 and abs(p.x)<back_width))
 return top or band or bottom
remove=[f for f in bm.faces if not all(covered(v) for v in f.verts)]
bmesh.ops.delete(bm,geom=remove,context='FACES');loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.normal_update()
for v in bm.verts:v.co+=v.normal*.004
mesh=bpy.data.meshes.new('Continuous refined MPFB foundation');bm.to_mesh(mesh);bm.free();bpy.data.meshes.remove(source);mesh.update()
old=bpy.data.objects['Opaque fitted bra and thong foundation'];old.name='Retained prior foundation candidate';old['street_source_only']=True;old.hide_render=True;old.hide_set(True)
obj=bpy.data.objects.new('Opaque fitted bra and thong foundation',mesh);bpy.context.collection.objects.link(obj)
obj.parent=body.parent;obj.matrix_parent_inverse=body.matrix_parent_inverse.copy();obj.matrix_basis=body.matrix_basis.copy()
for group in body.vertex_groups:obj.vertex_groups.new(name=group.name)
obj.modifiers.new('Original MPFB rig','ARMATURE').object=rig
mesh.materials.append(old.data.materials[0])
for face in mesh.polygons:face.use_smooth=True
obj['construction']='Refined complete-body surface with continuous opaque bands and interpolated MPFB weights'
if len(mesh.vertices)<1000:raise RuntimeError('Unexpected foundation size; candidate not saved')
retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path));print('INDIAN_FOUNDATION_REBUILD',slug,'vertices',len(mesh.vertices),'faces',len(mesh.polygons),flush=True)
