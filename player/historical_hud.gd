extends Control
## Original field-journal HUD: engraved brass rules, restrained ink panels and serif headings.
## Keeps the existing inventory, interaction and survival nodes/signals intact.
const SERIF = preload("res://assets/ui/fonts/CormorantGaramond.ttf")
const IVORY := Color(0.92,0.88,0.76)
const BRASS := Color(0.61,0.47,0.27)
const INK := Color(0.035,0.046,0.038,0.83)
var region_label: Label
var weapon_label: Label
var controls_label: Label
var status_label: Label
var player: CharacterBody3D
var heading: float = 0.0
var health: float = 100.0

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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_theme := Theme.new()
	hud_theme.default_font_size = 17
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
	content.get_node("TitleLabel").add_theme_font_override("font",SERIF)
	content.get_node("TitleLabel").add_theme_font_size_override("font_size",32)
	content.get_node("HintLabel").add_theme_font_size_override("font_size",13)
	var nameplate: Label = label("ARJUN",28,true)
	nameplate.name = "Nameplate"
	status_label = label("VITALITY",10)
	status_label.name = "VitalityLabel"
	region_label = label("SURYAGARH",27,true)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.name = "RegionHeading"
	weapon_label = label("UNARMED",24,true)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.name = "WeaponLabel"
	controls_label = label("Hold ~  Weapons    H  Stow / draw    V  View    M  Map    TAB  Satchel",12)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls_label.name = "ControlsLabel"
	for node in [$PrimaryInteractionLabel,$SecondaryInteractionLabel,$PickupMessageLabel]:
		node.add_theme_font_override("font",SERIF)
		node.add_theme_font_size_override("font_size",24)
		node.add_theme_color_override("font_outline_color",Color(0.025,0.035,0.025,0.95))
		node.add_theme_constant_override("outline_size",6)
	$GameTimeDebugLabel.add_theme_font_override("font",SERIF)
	$GameTimeDebugLabel.add_theme_font_size_override("font_size",21)
	$GameTimeDebugLabel.add_theme_color_override("font_outline_color",Color(0.03,0.04,0.03,0.85))
	$GameTimeDebugLabel.add_theme_constant_override("outline_size",4)
	resized.connect(_layout)
	_layout()
	queue_redraw()

func place(node: Control, p: Vector2, extent: Vector2) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	node.position = p
	node.size = extent

func _layout() -> void:
	if not is_instance_valid(region_label): return
	place($Nameplate,Vector2(32,size.y-160),Vector2(240,36))
	place(status_label,Vector2(34,size.y-122),Vector2(250,16))
	place($SurvivalHUD,Vector2(30,size.y-94),Vector2(286,68))
	place(region_label,Vector2(size.x/2-220,19),Vector2(440,38))
	place($GameTimeDebugLabel,Vector2(size.x-232,22),Vector2(202,64))
	place(weapon_label,Vector2(size.x-450,size.y-114),Vector2(420,34))
	place(controls_label,Vector2(size.x-610,size.y-46),Vector2(580,25))
	place($InventoryPanel,Vector2((size.x-640)/2,(size.y-420)/2),Vector2(640,420))
	place($PrimaryInteractionLabel,Vector2(size.x/2-250,size.y*0.62),Vector2(500,38))
	place($SecondaryInteractionLabel,Vector2(size.x/2-250,size.y*0.62+36),Vector2(500,32))
	place($PickupMessageLabel,Vector2(size.x/2-280,size.y*0.76),Vector2(560,40))

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera: heading = fposmod(-rad_to_deg(camera.global_rotation.y),360.0)
	var combat: Node = player.get_node_or_null("CombatComponent")
	if combat:
		health = combat.health
		weapon_label.text = combat.get_hud_text()
		controls_label.text = "1  Talwar    2  Enfield    3  Unarmed    R  Reload    M  Map    TAB  Satchel"
	else:
		var character := player.get_node_or_null("VisualRoot/CharacterVisual")
		weapon_label.text = character.equipment.held_name() if character and character.equipment else "STOWED"
	var rifle := player.get_node_or_null("RifleCombat")
	if rifle:
		weapon_label.text = rifle.get_hud_text()
		controls_label.text = "RMB Aim · LMB Fire · R Reload · H Stow · M Map · ~ Weapons"
	var equipment: Node = player.get_node("VisualRoot/CharacterVisual").equipment
	if equipment and not equipment.stowed and equipment.selected == 2:
		weapon_label.text = "BOW · %d ARROWS" % player.inventory.get_item_count("arrow")
		controls_label.text = "Hold RMB Draw · LMB Loose · H Stow · ~ Weapons"
	elif equipment and not equipment.stowed and equipment.selected == 3:
		var pistol: Node = player.get_node("PistolCombat")
		weapon_label.text = pistol.get_hud_text()
		controls_label.text = "Hold RMB Aim · LMB Fire · R Reload · H Stow · ~ Weapons"
	var world: Node = player.get_parent()
	var location: Label = world.get_node_or_null("LandscapeUI/Location") as Label
	if location:
		var parts: PackedStringArray = location.text.split("\n")[0].split("/")
		region_label.text = parts[parts.size()-1].strip_edges().to_upper()
	queue_redraw()

func diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)]),color,1.0,true)

func _draw() -> void:
	var rifle := player.get_node_or_null("RifleCombat")
	var bow: Node = player.get_node_or_null("BowCombat")
	var pistol: Node = player.get_node_or_null("PistolCombat")
	if (rifle and rifle.aiming) or (bow and bow.aiming) or (pistol and pistol.aiming):
		var center := size*.5
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			draw_line(center-axis*8,center-axis*3,IVORY,2)
			draw_line(center+axis*3,center+axis*8,IVORY,2)
	var y: float = size.y-172
	draw_style_box(box(INK,Color(BRASS,0.45)),Rect2(20,y,310,153))
	draw_line(Vector2(33,y+8),Vector2(318,y+8),BRASS,1,true)
	diamond(Vector2(175,y+8),3,IVORY)
	draw_rect(Rect2(34,size.y-103,280,3),Color(0.24,0.23,0.18))
	draw_rect(Rect2(34,size.y-103,280*clampf(health/100.0,0,1),3),Color(0.64,0.25,0.17))
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
	var font: Font = ThemeDB.fallback_font
	for offset in range(-90,91,15):
		var angle: float = fposmod(floor(heading/15.0)*15.0+offset,360.0)
		var x: float = cx + (angle_difference(deg_to_rad(heading),deg_to_rad(angle))*180/PI)*1.6
		if absf(x-cx)>145: continue
		var cardinal: bool = int(angle)%90 == 0
		draw_line(Vector2(x,73),Vector2(x,79 if cardinal else 76),Color(IVORY,0.7),1,true)
		if cardinal:
			var direction: String = ["N","E","S","W"][int(angle)/90]
			draw_string(font,Vector2(x-5,94),direction,HORIZONTAL_ALIGNMENT_LEFT,-1,11,IVORY)
	draw_line(Vector2(size.x-295,size.y-69),Vector2(size.x-30,size.y-69),BRASS,1,true)
	# A small unobtrusive sight; gun state adds its own aim feedback.
	if is_instance_valid(player) and not $InventoryPanel.visible:
		draw_circle(size/2,1.3,Color(IVORY,0.7))
