extends Node
## One selected object, no mesh clones or mutations of shared source materials.
var target: Interactable
var entries: Array[Dictionary]=[]
var overlay: Control
var visual_root: Node3D
var actor: CharacterBody3D
const SHADER=preload("res://interaction/focus_glow.gdshader")

func _ready() -> void:
	overlay=get_parent();actor=overlay.actor
	process_mode=Node.PROCESS_MODE_ALWAYS

func _physics_process(_delta: float) -> void:
	var chosen: Interactable
	if is_instance_valid(overlay.target):chosen=overlay.target
	if get_tree().paused or not overlay.is_visible_in_tree() or actor==null or actor.get_meta("opening_active",false) or actor.get_meta("story_cinematic",false) or actor.get_meta("map_open",false) or actor.get_meta("weapon_wheel_open",false) or (actor.get_node_or_null("UI/HUDRoot/InventoryPanel")!=null and actor.get_node("UI/HUDRoot/InventoryPanel").is_open()):chosen=null
	if is_instance_valid(chosen):
		var anchor: Vector3=chosen.interaction_anchor()
		if not chosen.interaction_available() or actor.global_position.distance_to(chosen.interaction_anchor() if chosen.is_in_group("house_doors") else chosen.global_position)>chosen.interaction_max_distance+.1:chosen=null
		else:
			var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.35,anchor,1,[actor.get_rid(),chosen.get_rid()])
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				var root: Node3D=visual_root if chosen==target and is_instance_valid(visual_root) else chosen.highlight_visual_root()
				if hit.collider!=root and not root.is_ancestor_of(hit.collider):chosen=null
	set_focus(chosen)

func set_focus(chosen: Interactable) -> void:
	if not is_instance_valid(chosen):chosen=null
	if is_instance_valid(target) and chosen==target:return
	if chosen==null and target==null and entries.is_empty():return
	clear()
	target=chosen
	if target==null:return
	visual_root=target.highlight_visual_root()
	if is_instance_valid(visual_root):
		collect(visual_root,visual_root)
		var bounds:=AABB()
		var first:=true
		for entry in entries:
			var relative: Transform3D=visual_root.global_transform.affine_inverse()*entry.mesh.global_transform
			var box: AABB=relative*entry.mesh.get_aabb()
			bounds=box if first else bounds.merge(box)
			first=false
			entry.installed.set_shader_parameter("mesh_to_focus",relative)
		for entry in entries:
			entry.installed.set_shader_parameter("focus_min",bounds.position)
			entry.installed.set_shader_parameter("focus_size",bounds.size)

func collect(node: Node, root: Node) -> void:
	if node!=root and (node is Interactable or node.is_in_group("combat_actors")):return
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var material:=ShaderMaterial.new();material.shader=SHADER
		material.next_pass=node.material_overlay
		entries.append({"mesh":node,"prior":node.material_overlay,"installed":material})
		node.material_overlay=material
	for child in node.get_children():collect(child,root)

func clear() -> void:
	for entry in entries:
		if is_instance_valid(entry.mesh) and entry.mesh.material_overlay==entry.installed:entry.mesh.material_overlay=entry.prior
	entries.clear();target=null;visual_root=null

func _exit_tree() -> void:
	clear()
