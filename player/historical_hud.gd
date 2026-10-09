extends Control
## Original field-journal HUD: engraved brass rules, restrained ink panels and serif headings.
## Keeps the existing inventory, interaction and survival nodes/signals intact.
const SERIF = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const BOLD = preload("res://assets/ui/fonts/MFBOldstyle-Bold.otf")
const IVORY := Color(0.92,0.88,0.76)
const BRASS := Color(0.61,0.47,0.27)
const INK := Color(0.035,0.046,0.038,0.38)
var weapon_label: Label
var status_label: Label
var money_label: Label
var player: CharacterBody3D
var heading: float = 0.0
var health: float = 100.0
var health_trail: float = 100.0
var sight_pulse := 0.0
var sight_recoil := 0.0
var human_target := false

func box(color: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(width)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func label(text_value: String, font_size: int, serif: bool = false) -> Label:
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",IVORY)
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,0.85))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	if serif: node.add_theme_font_override("font",SERIF)
	add_child(node)
	return node

func _ready() -> void:
	player = get_parent().get_parent() as CharacterBody3D
	health_trail = player.health
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_theme := Theme.new()
	hud_theme.default_font_size = 17
	hud_theme.default_font = SERIF
	hud_theme.set_color("font_color","Label",IVORY)
	hud_theme.set_color("font_color","Button",IVORY)
	hud_theme.set_color("font_disabled_color","Button",Color(0.48,0.48,0.41))
	hud_theme.set_stylebox("normal","Button",box(Color(0.08,0.095,0.075),BRASS))
	hud_theme.set_stylebox("hover","Button",box(Color(0.16,0.18,0.12),IVORY))
	hud_theme.set_stylebox("pressed","Button",box(Color(0.20,0.16,0.09),BRASS))
	hud_theme.set_stylebox("disabled","Button",box(Color(0.055,0.065,0.05),Color(0.25,0.26,0.21)))
	var focus := box(Color(0,0,0,0),IVORY,2)
	hud_theme.set_stylebox("focus","Button",focus)
	hud_theme.set_stylebox("background","ProgressBar",box(Color(0.10,0.12,0.095),Color(0,0,0,0),0))
	hud_theme.set_stylebox("fill","ProgressBar",box(Color(0.5,0.63,0.57),Color(0,0,0,0),0))
	var line := StyleBoxLine.new()
	line.color = BRASS
	line.thickness = 1
	hud_theme.set_stylebox("separator","HSeparator",line)
	theme = hud_theme
	$InventoryPanel.add_theme_stylebox_override("panel",box(Color(0.045,0.055,0.043,0.97),BRASS))
	var content: VBoxContainer = $InventoryPanel/ContentMargin/Content
	content.add_theme_constant_override("separation",22)
	content.get_node("TitleLabel").text = "THE TRAVELLER’S SATCHEL"
	content.get_node("TitleLabel").add_theme_font_override("font",BOLD)
	content.get_node("TitleLabel").add_theme_font_size_override("font_size",32)
	content.get_node("HintLabel").add_theme_font_size_override("font_size",13)
	status_label = label("VITALITY",10)
	status_label.name = "VitalityLabel"
	status_label.visible = false
	money_label = label("0",14,true)
	money_label.name = "MoneyLabel"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_label = label("UNARMED",24,true)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.name = "WeaponLabel"
	for node in [$PrimaryInteractionLabel,$SecondaryInteractionLabel,$PickupMessageLabel]:
		node.add_theme_font_override("font",SERIF)
		node.add_theme_font_size_override("font_size",24)
		node.add_theme_color_override("font_outline_color",Color(0.025,0.035,0.025,0.95))
		node.add_theme_constant_override("outline_size",6)
	resized.connect(_layout)
	_layout()
	queue_redraw()

func place(node: Control, p: Vector2, extent: Vector2) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	node.position = p
	node.size = extent

func _layout() -> void:
	if not is_instance_valid(weapon_label): return
	place(status_label,Vector2(32,size.y-301),Vector2(236,16))
	place(money_label,Vector2(199,size.y-76),Vector2(109,28))
	place($SurvivalHUD,Vector2(20,size.y-164),Vector2(144,144))
	place(weapon_label,Vector2(size.x-450,size.y-234),Vector2(420,34))
	place($InventoryPanel,Vector2((size.x-640)/2,(size.y-420)/2),Vector2(640,420))
	place($PrimaryInteractionLabel,Vector2(size.x/2-250,size.y*0.62),Vector2(500,38))
	place($SecondaryInteractionLabel,Vector2(size.x/2-250,size.y*0.62+36),Vector2(500,32))
	place($PickupMessageLabel,Vector2(size.x/2-280,size.y*0.18),Vector2(560,40))

func _process(delta: float) -> void:
	_update_gun_sight(delta)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera: heading = fposmod(-rad_to_deg(camera.global_rotation.y),360.0)
	var combat: Node = player.get_node_or_null("CombatComponent")
	money_label.text = str(player.inventory.get_item_count("rupees"))
	health = player.health
	health_trail = health if health >= health_trail else move_toward(health_trail,health,delta*32.0)
	if combat:
		weapon_label.text = combat.get_hud_text()
	else:
		var character := player.get_node_or_null("VisualRoot/CharacterVisual")
		weapon_label.text = character.equipment.held_name() if character and character.equipment else "STOWED"
	var rifle := player.get_node_or_null("RifleCombat")
	if rifle:
		weapon_label.text = rifle.get_hud_text()
	var equipment: Node = player.get_node("VisualRoot/CharacterVisual").equipment
	if equipment and not equipment.stowed and equipment.selected == 2:
		weapon_label.text = "BOW · %d ARROWS" % player.inventory.get_item_count("arrow")
	elif equipment and not equipment.stowed and equipment.selected == 3:
		var pistol: Node = player.get_node("PistolCombat")
		weapon_label.text = pistol.get_hud_text()
	if equipment and not equipment.stowed and equipment.selected in [1,3,5]:
		weapon_label.text = {1:"ENFIELD",3:"ADAMS REVOLVER",5:"DOUBLE GUN"}[equipment.selected]
		place(weapon_label,Vector2(size.x-303,size.y-331),Vector2(258,28))
	else:
		place(weapon_label,Vector2(size.x-450,size.y-234),Vector2(420,34))
	queue_redraw()

func _update_gun_sight(delta: float) -> void:
	var gear: Node = player.get_node("VisualRoot/CharacterVisual").equipment
	var aiming_gun: bool = gear != null and not gear.stowed and ((gear.selected == 1 and player.get_node("RifleCombat").aiming) or (gear.selected == 3 and player.get_node("PistolCombat").aiming) or (gear.selected == 5 and player.get_node("DoubleGunCombat").aiming))
	human_target = false
	if aiming_gun:
		var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
		var from: Vector3 = camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 350.0)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var node: Node = hit.collider as Node
			while node != null and node != player:
				if node.is_in_group("human_npcs"):
					human_target = true
					break
				node = node.get_parent()
	sight_pulse = move_toward(sight_pulse, 1.0 if human_target else 0.0, delta * 5.0)
	sight_recoil = move_toward(sight_recoil,clampf(gear.recoil/0.075,0.0,1.0) if aiming_gun else 0.0,delta*20.0)

func gun_sight_radius(pistol_sight: bool) -> float:
	return lerpf(17.0 if pistol_sight else 12.0,9.0 if pistol_sight else 6.5,sight_pulse)+sight_recoil*(6.0 if pistol_sight else 4.0)

func diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)]),color,1.0,true)

func _draw_gun_silhouette(at: Vector2, pistol: bool, double_barrel := false) -> void:
	var shape := PackedVector2Array()
	if pistol:
		shape = PackedVector2Array([Vector2(0,9),Vector2(26,9),Vector2(29,5),Vector2(43,5),Vector2(46,9),Vector2(68,9),Vector2(68,13),Vector2(47,13),Vector2(44,18),Vector2(39,18),Vector2(36,31),Vector2(24,31),Vector2(27,18),Vector2(21,16),Vector2(0,14)])
	else:
		shape = PackedVector2Array([Vector2(0,13),Vector2(30,6),Vector2(45,10),Vector2(58,9),Vector2(64,5),Vector2(143,5),Vector2(143,9),Vector2(63,10),Vector2(57,15),Vector2(47,16),Vector2(43,20),Vector2(28,17),Vector2(8,23),Vector2(0,21)])
	for i in shape.size(): shape[i] += at
	draw_colored_polygon(shape,Color(.96,.95,.91))
	if pistol:
		draw_circle(at+Vector2(37,11),5.0,Color(.08,.08,.08))
		draw_arc(at+Vector2(34,19),7,0,PI,10,Color(.05,.05,.05),1.5,true)
	else:
		draw_arc(at+Vector2(52,15),7,0,PI,10,Color(.05,.05,.05),1.5,true)
		if double_barrel:
			draw_line(at+Vector2(65,12),at+Vector2(141,12),Color(.96,.95,.91),2.0,true)

func _draw_ammo() -> void:
	var gear: Node = player.get_node("VisualRoot/CharacterVisual").equipment
	if gear == null or gear.stowed or gear.selected not in [1,3,5]: return
	var sidearm: bool = gear.selected == 3
	var double_barrel: bool = gear.selected == 5
	var gun: Node = player.get_node("PistolCombat") if sidearm else (player.get_node("DoubleGunCombat") if double_barrel else player.get_node("RifleCombat"))
	if gun == null: return
	var loaded: int = gun.rounds
	var capacity: int = 5 if sidearm else (2 if double_barrel else 1)
	var spare: int = player.inventory.get_item_count("pistol_ball" if sidearm else ("shot_charge" if double_barrel else "paper_cartridges"))
	var x: float = size.x-318
	var y: float = size.y-340
	draw_style_box(box(Color(.04,.045,.044,.45),Color(BRASS,.42)),Rect2(x,y,288,126))
	draw_line(Vector2(x+16,y+42),Vector2(x+272,y+42),Color(IVORY,.35),1,true)
	_draw_gun_silhouette(Vector2(x+19,y+70),sidearm,double_barrel)
	var font: Font = SERIF
	draw_string(font,Vector2(x+178,y+85),str(loaded),HORIZONTAL_ALIGNMENT_RIGHT,55,38,Color(.98,.97,.93))
	draw_string(font,Vector2(x+234,y+85),str(spare),HORIZONTAL_ALIGNMENT_LEFT,34,19,Color(.92,.91,.86))
	draw_line(Vector2(x+204,y+61),Vector2(x+204,y+83),Color(IVORY,.52),1,true)
	for i in capacity:
		var bullet_x: float = x+181+float(i)*16
		var bullet_color := Color(.93,.91,.83) if i<loaded else Color(.93,.91,.83,.22)
		draw_rect(Rect2(bullet_x,y+102,7,12),bullet_color)
		draw_arc(Vector2(bullet_x+3.5,y+102),3.5,PI,TAU,9,bullet_color,1.2,true)
	if gun.reload_remaining > 0.0:
		draw_string(font,Vector2(x+19,y+115),"RELOADING",HORIZONTAL_ALIGNMENT_LEFT,130,12,BRASS)

func _draw() -> void:
	_draw_ammo()
	var rifle := player.get_node_or_null("RifleCombat")
	var bow: Node = player.get_node_or_null("BowCombat")
	var pistol: Node = player.get_node_or_null("PistolCombat")
	var double_gun: Node = player.get_node_or_null("DoubleGunCombat")
	var gear: Node = player.get_node("VisualRoot/CharacterVisual").equipment
	var gun_aim: bool = gear != null and not gear.stowed and ((gear.selected == 1 and rifle and rifle.aiming) or (gear.selected == 3 and pistol and pistol.aiming) or (gear.selected == 5 and double_gun and double_gun.aiming))
	if gun_aim:
		var pistol_sight: bool = gear != null and gear.selected == 3
		var center := size * .5
		var radius := gun_sight_radius(pistol_sight)
		var color := Color(0.85,0.57,0.32) if human_target else IVORY
		for angle in [0.0, PI*.5, PI, PI*1.5]:
			var axis := Vector2.from_angle(angle)
			draw_line(center+axis*radius,center+axis*(radius+(10.0 if pistol_sight else 8.0)),color,2.5 if pistol_sight else 2.0,true)
	elif bow and bow.aiming:
		var center := size*.5
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			draw_line(center-axis*8,center-axis*3,IVORY,2)
			draw_line(center+axis*3,center+axis*8,IVORY,2)
	# Thin framed health strip follows the reference; delayed fill makes damage readable.
	var track := Rect2(178,size.y-95,140,7)
	draw_rect(track.grow(2),Color(0.025,0.03,0.025,0.8))
	draw_rect(track.grow(1),Color(IVORY,0.42),false,1)
	draw_rect(track,Color(0.10,0.12,0.10,0.8))
	var fraction: float = clampf(health/player.MAX_HEALTH,0,1)
	var trail: float = clampf(health_trail/player.MAX_HEALTH,0,1)
	draw_rect(Rect2(track.position,Vector2(track.size.x*trail,track.size.y)),Color(0.65,0.44,0.22))
	var health_color := IVORY if fraction>0.4 else (Color(0.84,0.61,0.31) if fraction>0.2 else Color(0.81,0.28,0.20))
	draw_rect(Rect2(track.position,Vector2(track.size.x*fraction,track.size.y)),health_color)
	for i in range(1,5):
		var x: float = track.position.x+track.size.x*float(i)/5.0
		draw_line(Vector2(x,track.position.y),Vector2(x,track.end.y),Color(0.045,0.05,0.04,0.7),1)
	# The purse shares the health strip's alignment and engraved brass/ink treatment.
	var purse := Rect2(178,size.y-76,140,28)
	draw_style_box(box(Color(0.035,0.042,0.035,0.76),Color(BRASS,0.85)),purse)
	draw_line(purse.position+Vector2(1,1),purse.position+Vector2(139,1),Color(IVORY,0.45),1,true)
	var coin := purse.position+Vector2(14,14)
	draw_circle(coin,7,Color(BRASS,0.22))
	draw_arc(coin,7,0,TAU,32,IVORY,1,true)
	draw_arc(coin,4.5,0,TAU,24,Color(BRASS,0.85),1,true)
	draw_line(coin+Vector2(-1,-2),coin+Vector2(1,2),IVORY,1,true)
	var mount: Node = (player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)
	if is_instance_valid(mount) and mount.is_in_group("horses"):
		var horse_y: float = size.y-211
		draw_style_box(box(INK,Color(BRASS,0.45)),Rect2(20,horse_y,310,32))
		draw_string(SERIF,Vector2(34,horse_y+19),"HORSE STAMINA",HORIZONTAL_ALIGNMENT_LEFT,-1,17,IVORY)
		draw_rect(Rect2(185,horse_y+13,128,6),Color(0.24,0.23,0.18))
		draw_rect(Rect2(185,horse_y+13,128*clampf(mount.stamina/mount.MAX_STAMINA,0,1),6),Color(0.69,0.56,0.31))
	var cx: float = size.x/2
	draw_line(Vector2(cx-165,63),Vector2(cx+165,63),Color(BRASS,0.8),1,true)
	diamond(Vector2(cx,63),4,IVORY)
	var font: Font = SERIF
	for offset in range(-90,91,15):
		var angle: float = fposmod(floor(heading/15.0)*15.0+offset,360.0)
		var x: float = cx + (angle_difference(deg_to_rad(heading),deg_to_rad(angle))*180/PI)*1.6
		if absf(x-cx)>145: continue
		var cardinal: bool = int(angle)%90 == 0
		draw_line(Vector2(x,73),Vector2(x,79 if cardinal else 76),Color(IVORY,0.7),1,true)
		if cardinal:
			var direction: String = ["N","E","S","W"][int(angle)/90]
			draw_string(font,Vector2(x-5,94),direction,HORIZONTAL_ALIGNMENT_LEFT,-1,11,IVORY)
	if gear == null or gear.stowed or gear.selected not in [1,3]:
		draw_line(Vector2(size.x-295,size.y-219),Vector2(size.x-30,size.y-219),BRASS,1,true)
