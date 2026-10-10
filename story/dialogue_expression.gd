extends RefCounted
## Temporary expression deltas on duplicated complete MPFB meshes; no topology removal.
var entries: Array[Dictionary]=[]
func configure(model: Node3D) -> void:
    var head_top:=0.0
    for node in model.find_children("*","MeshInstance3D",true,false):
        if "body" in node.name.to_lower():head_top=maxf(head_top,node.get_aabb().end.y)
    if head_top<=0:return
    var eye_height: float=head_top-.15
    for node in model.find_children("*","MeshInstance3D",true,false):
        if "eyes" in node.name.to_lower():eye_height=node.get_aabb().get_center().y
    for node in model.find_children("*","MeshInstance3D",true,false):
        var label: String=node.name.to_lower()
        if not ("body" in label or "eyebrow" in label or "moustache" in label):continue
        var source:=node.mesh as ArrayMesh
        if source==null or source.get_blend_shape_count()>0:continue
        var mesh:=ArrayMesh.new();mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
        mesh.add_blend_shape("dialogue_concern");mesh.add_blend_shape("dialogue_disdain");mesh.add_blend_shape("dialogue_anger");mesh.add_blend_shape("dialogue_speech");mesh.add_blend_shape("dialogue_blink")
        for surface in source.get_surface_count():
            var base: Array=source.surface_get_arrays(surface)
            var points: PackedVector3Array=base[Mesh.ARRAY_VERTEX]
            var shapes: Array[Array]=[]
            for emotion in ["concern","disdain","anger","speech","blink"]:
                var shape: Array=[];shape.resize(Mesh.ARRAY_MAX)
                var offsets:=PackedVector3Array();offsets.resize(points.size())
                for i in points.size():
                    var p:=points[i]
                    if p.z<.10:continue
                    var brow: float=exp(-pow((p.y-(eye_height+.018))/.018,2))*exp(-pow(p.x/.065,4))
                    var mouth: float=exp(-pow((p.y-(eye_height-.105))/.013,2))*exp(-pow(p.x/.04,4))
                    if emotion=="concern":offsets[i].y=brow*.003*(1.0-smoothstep(.01,.05,absf(p.x)))-mouth*.0015*smoothstep(.01,.03,absf(p.x))
                    elif emotion=="disdain":offsets[i].y=-brow*.0015+mouth*.002*smoothstep(0,.03,p.x)
                    elif emotion=="anger":offsets[i].y=-brow*.003*(1.0-smoothstep(.015,.055,absf(p.x)))
                    elif emotion=="speech":
                        offsets[i].y=-mouth*.004*(1.0-smoothstep(eye_height-.108,eye_height-.095,p.y))
                        offsets[i].z=mouth*.0008
                    elif "body" in label:
                        var eye: float=exp(-pow((absf(p.x)-.030)/.018,4))
                        var lid: float=exp(-pow((p.y-eye_height)/.010,4))*eye
                        offsets[i].y=(eye_height-p.y)*lid*.85
                var shaped: PackedVector3Array=points.duplicate()
                for i in shaped.size():shaped[i]+=offsets[i]
                shape[Mesh.ARRAY_VERTEX]=shaped
                if base[Mesh.ARRAY_NORMAL]!=null:
                    shape[Mesh.ARRAY_NORMAL]=base[Mesh.ARRAY_NORMAL]
                if base[Mesh.ARRAY_TANGENT]!=null:
                    shape[Mesh.ARRAY_TANGENT]=base[Mesh.ARRAY_TANGENT]
                shapes.append(shape)
            mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),base,shapes,{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
            mesh.surface_set_material(surface,source.surface_get_material(surface))
        node.mesh=mesh;entries.append({"node":node,"source":source})
func apply(concern: float, disdain: float, anger: float=0.0, speech: float=0.0, blink: float=0.0) -> void:
    var weights: Array[float]=[clampf(concern,0,1),clampf(disdain,0,1),clampf(anger,0,1),clampf(speech,0,1),clampf(blink,0,1)]
    var total:=0.0
    for value in weights:total+=value
    for entry in entries:
        if is_instance_valid(entry.node):
            for index in weights.size():entry.node.set_blend_shape_value(index,weights[index]/maxf(total,1.0))

static func speech_weight(age: float, duration: float) -> float:
    # Silent subtitle acting: irregular syllable motion with breathing gaps, no audio claim.
    var envelope:=smoothstep(.15,.45,age)*(1.0-smoothstep(duration-.65,duration-.15,age))
    var pause:=1.0-smoothstep(.78,.96,fmod(age,2.3)/2.3)
    return envelope*pause*(.28+.30*pow(sin(age*15.7),2)+.16*pow(sin(age*9.3+.8),2))

static func blink_weight(age: float, offset: float=0.0) -> float:
    var phase:=fmod(age+offset,4.7)
    return pow(sin(clampf(phase/.19,0,1)*PI),2) if phase<.19 else 0.0

func restore() -> void:
    for entry in entries:
        if is_instance_valid(entry.node):entry.node.mesh=entry.source
    entries.clear()
