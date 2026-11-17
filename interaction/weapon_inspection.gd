extends CanvasLayer
## Read-only mesh preview; the original pickup is consumed only by a confirmed choice.
var pickup: Interactable
var actor: CharacterBody3D
var pivot: Node3D
var camera: Camera3D
var old_mouse: int
var old_paused: bool
var closed:=false
var buttons: Array[Button]=[]

static func open_for(source: Interactable, player: CharacterBody3D) -> void:
	if player.global_position.distance_to(source.global_position)>source.interaction_max_distance:return
	if player.get_meta("weapon_inspection_open",false) or player.get_tree().paused:return
	if (player.has_meta("mounted_vehicle") and player.get_meta("mounted_vehicle")!=null) or player.get_meta("climbing",false):return
	var window: CanvasLayer=load("res://interaction/weapon_inspection.gd").new()
	window.pickup=source;window.actor=player
	player.get_node("UI").add_child(window)

func _ready() -> void:
	layer=80
	process_mode=Node.PROCESS_MODE_ALWAYS
	old_mouse=Input.mouse_mode
	old_paused=get_tree().paused
	actor.set_meta("weapon_inspection_open",true)
	get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var backdrop:=ColorRect.new()
	backdrop.color=Color(.012,.018,.02,.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,32)
	backdrop.add_child(margin)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	margin.add_child(column)
	var title:=Label.new()
	title.text={"enfield":"Enfield rifle","talwar":"Talwar","bow":"Bow and quiver","pistol":"Adams pistol","double_gun":"Double-barrel gun","utility_knife":"Utility knife","spear":"Spear"}.get(pickup.weapon_id,pickup.weapon_id.capitalize())
	title.add_theme_font_override("font",preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf"))
	title.add_theme_font_size_override("font_size",30)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var view:=SubViewportContainer.new()
	view.stretch=true
	view.size_flags_vertical=Control.SIZE_EXPAND_FILL
	view.custom_minimum_size=Vector2(0,200)
	column.add_child(view)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(960,540)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.add_child(viewport)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.025,.035,.04)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.8,.84,.9)
	environment.environment.ambient_light_energy=.8
	viewport.add_child(environment)
	pivot=Node3D.new();viewport.add_child(pivot)
	var bounds:=copy_meshes(pickup,pickup.global_transform.affine_inverse(),pivot)
	if bounds.size.length()>.0001:
		var normalise:=1.7/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		pivot.scale=Vector3.ONE*normalise
		for child in pivot.get_children():child.position-=(bounds.position+bounds.size*.5)
	var presentation:=Basis.IDENTITY
	if bounds.size.y>bounds.size.x and bounds.size.y>=bounds.size.z:presentation=Basis(Vector3.FORWARD,PI*.5)
	elif bounds.size.z>bounds.size.x:presentation=Basis(Vector3.UP,PI*.5)
	pivot.basis=Basis.from_euler(Vector3(.12,-.35,-.15))*presentation*pivot.basis
	camera=Camera3D.new();camera.position=Vector3(0,0,2.7);camera.fov=48;viewport.add_child(camera)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.6;viewport.add_child(light)
	var hint:=Label.new();hint.text="Drag to rotate · Scroll to zoom · Esc to leave"
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(hint)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",24);column.add_child(row)
	for caption in ["Leave","Keep","Equip"]:
		var button:=Button.new();button.text=caption;button.custom_minimum_size=Vector2(150,48)
		row.add_child(button);buttons.append(button)
	buttons[0].pressed.connect(close)
	buttons[1].pressed.connect(confirm.bind(false))
	buttons[2].pressed.connect(confirm.bind(true))
	buttons[0].grab_focus()
	view.gui_input.connect(preview_input)

func copy_meshes(source: Node, inverse: Transform3D, destination: Node3D) -> AABB:
	var bounds:=AABB()
	var first:=true
	var nodes: Array[Node]=[source]
	while not nodes.is_empty():
		var node: Node=nodes.pop_back()
		if node is MeshInstance3D and node.mesh!=null:
			var mesh:=MeshInstance3D.new()
			mesh.mesh=node.mesh;mesh.material_override=node.material_override
			for surface in node.mesh.get_surface_count():mesh.set_surface_override_material(surface,node.get_surface_override_material(surface))
			mesh.transform=inverse*node.global_transform
			destination.add_child(mesh)
			var box: AABB=mesh.transform*mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		for child in node.get_children():nodes.append(child)
	return bounds

func preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		pivot.rotation.y+=event.relative.x*.009
		pivot.rotation.x=clampf(pivot.rotation.x+event.relative.y*.009,-PI,PI)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.position.z=maxf(1.4,camera.position.z-.15)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.position.z=minf(4.5,camera.position.z+.15)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();close()

func _process(_delta: float) -> void:
	if not is_instance_valid(pickup) or not is_instance_valid(actor):close()

func confirm(equip: bool) -> void:
	if closed:return
	if is_instance_valid(pickup) and is_instance_valid(actor):pickup.collect(actor,equip)
	close()

func close() -> void:
	if closed:return
	closed=true
	if is_instance_valid(actor):actor.set_meta("weapon_inspection_open",false)
	get_tree().paused=old_paused
	Input.mouse_mode=old_mouse
	queue_free()

func _exit_tree() -> void:
	if not closed:
		if is_instance_valid(actor):actor.set_meta("weapon_inspection_open",false)
		get_tree().paused=old_paused
		Input.mouse_mode=old_mouse
