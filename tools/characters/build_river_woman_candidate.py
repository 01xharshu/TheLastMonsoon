"""Separate MPFB river-clothing deformation study; preserves donor and live assets."""
import bpy, hashlib, json, math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/NPCs/river_woman'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/village_woman/village_woman_motion_candidate.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig']
body=bpy.data.objects['village_woman_MakeHuman_body']
import sys
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body
retain_complete_body(body)
rig.data.pose_position='REST'
bpy.context.view_layer.update()
bone_names=set(rig.data.bones.keys())
# Use only actual MPFB body surface vertices carrying deform weights; helpers
# and genital helpers are excluded from transfer and foundation construction.
body_group=body.vertex_groups['body'].index
valid=[v for v in body.data.vertices if any(g.group==body_group and g.weight>.5 for g in v.groups)]
tree=KDTree(len(valid))
for i,v in enumerate(valid): tree.insert(v.co,i)
tree.balance()
def transfer(obj):
    obj.vertex_groups.clear()
    for v in obj.data.vertices:
        weights={};total=0
        for co,index,distance in tree.find_n(v.co,6):
            source=valid[index]
            factor=1/max(distance,.01)**3
            for assignment in source.groups:
                name=body.vertex_groups[assignment.group].name
                if name in bone_names:
                    weights[name]=weights.get(name,0)+assignment.weight*factor
                    total+=assignment.weight*factor
        for name,weight in weights.items():
            if weight/total>.001:
                (obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)).add([v.index],weight/total,'REPLACE')

for name in ['Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse']:
    obj=bpy.data.objects[name]
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    # Add vertical support topology before weight transfer. A candidate, not
    # cloth simulation: full deep-motion shape correction remains reviewable.
    modifier=obj.modifiers.new('Cloth support topology','SUBSURF')
    modifier.subdivision_type='SIMPLE';modifier.levels=2
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    transfer(obj)
    for poly in obj.data.polygons:poly.use_smooth=True
    obj['fit_surface']='Original MPFB village woman; no body substitution'

# Remove the donor's modern blouse print. Keep the same fitted topology/body.
upper=bpy.data.objects['Fitted cotton upper base']
cotton=bpy.data.materials.new('River blouse plain cotton');cotton.use_nodes=True
shader=cotton.node_tree.nodes['Principled BSDF']
shader.inputs['Base Color'].default_value=(.29,.24,.095,1)
shader.inputs['Roughness'].default_value=.95
upper.data.materials.clear();upper.data.materials.append(cotton)
# Preserve opaque foundation from the same native body surface, using fitted
# bra and narrow rear/broad front brief regions; no visible anatomy is added.
vertices=[];faces=[];source_indices=[]
def accepted(v):
    x,y,z=v.co
    top=.995<z<1.17 and y<-.025 and abs(x)<.19
    band=.785<z<.825
    bottom=.64<z<.825 and ((y<-.025 and abs(x)<.105) or (y>=-.025 and abs(x)<.035))
    return top or band or bottom
for poly in body.data.polygons:
    if all(accepted(body.data.vertices[i]) for i in poly.vertices) and all(any(g.group==body_group and g.weight>.5 for g in body.data.vertices[i].groups) for i in poly.vertices):
        face=[]
        for index in poly.vertices:
            source=body.data.vertices[index]
            vertices.append(source.co+source.normal*.003)
            source_indices.append(index);face.append(len(vertices)-1)
        faces.append(face)
mesh=bpy.data.meshes.new('Native body opaque foundation');mesh.from_pydata(vertices,[],faces);mesh.update()
foundation=bpy.data.objects.new('Opaque fitted bra and brief foundation',mesh);bpy.context.collection.objects.link(foundation)
foundation.parent=rig
foundation.modifiers.new('Armature deformation','ARMATURE').object=rig
material=bpy.data.materials.new('Opaque undyed foundation cotton');material.diffuse_color=(.3,.24,.17,1);material.use_nodes=True
material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.3,.24,.17,1)
material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
foundation.data.materials.append(material)
for i,index in enumerate(source_indices):
    for assignment in body.data.vertices[index].groups:
        name=body.vertex_groups[assignment.group].name
        if name in bone_names:(foundation.vertex_groups.get(name) or foundation.vertex_groups.new(name=name)).add([i],assignment.weight,'REPLACE')
foundation['presentation']='Opaque adult foundation derived from original MPFB body; fit review open'
# Clothing correctives retain the entire native body in every pose.
from river_cloth_correctives import fit_river_cloth
fit_river_cloth(ROOT,rig,body,[upper]+[bpy.data.objects[n] for n in ['Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse']])
source=OUT/'river_woman_motion.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
# Bake helper exclusion and clothing-only masks. The full human body and
# separate opaque foundation are both exported.
masked={body}
depsgraph=bpy.context.evaluated_depsgraph_get()
for original in masked:
    mesh=bpy.data.meshes.new_from_object(original.evaluated_get(depsgraph),preserve_all_data_layers=True,depsgraph=depsgraph)
    cutout=bpy.data.objects.new(original.name+'_export_cutout',mesh);bpy.context.collection.objects.link(cutout)
    for group in original.vertex_groups:cutout.vertex_groups.new(name=group.name)
    cutout.parent=rig;cutout.matrix_parent_inverse=original.matrix_parent_inverse.copy();cutout.matrix_basis=original.matrix_basis.copy()
    cutout.modifiers.new('Armature deformation','ARMATURE').object=rig
rig.data.pose_position='POSE';rig.animation_data_create();rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj not in masked :obj.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=ROOT/'characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb'
runtime.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_apply=False)
report=dict(status='RIVER_CLOTHING_DEFORMATION_STUDY',source=str(source.relative_to(ROOT)),runtime=str(runtime.relative_to(ROOT)),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),foundation_faces=len(faces),donor='village_woman_motion_candidate.blend',visual_approved=False,motion_approved=False,in_world=False)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('RIVER_SOURCE',json.dumps(report))
