extends CanvasLayer
const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
var overlay: Control
var column: VBoxContainer
var previous_mouse_mode: Input.MouseMode
var previous_hud_visible := true
var page := "main"
@onready var world: Node3D = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = Style.make_theme()
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.035,0.028,0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 440
	column.add_theme_constant_override("separation",13)
	centre.add_child(column)
	overlay.hide()

func toggle() -> void:
	if overlay.visible: close()
	else: open()

func open() -> void:
	if overlay.visible: return
	var player: CharacterBody3D = world.get_node("Player")
	if player.get_meta("map_open",false) or player.get_meta("weapon_wheel_open",false): return
	if player.inventory_ui.is_open():
		player.inventory_ui.close_inventory()
	previous_hud_visible = player.get_node("UI/HUDRoot").visible
	player.get_node("UI/HUDRoot").hide()
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.show()
	show_main()
	get_tree().paused = true

func close() -> void:
	if not overlay.visible: return
	get_tree().paused = false
	overlay.hide()
	world.get_node("Player/UI/HUDRoot").visible = previous_hud_visible
	Input.mouse_mode = previous_mouse_mode

func _input(event: InputEvent) -> void:
	if not overlay.visible: return
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		if page == "main": close()
		else: show_main()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()

func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	page = "main"
	clear_content()
	column.add_child(Style.label("PAUSED",46))
	var resume: Button = Style.button("Resume",func(): close())
	column.add_child(resume)
	_focus_resume.call_deferred(resume)
	column.add_child(Style.button("Save Game",func(): show_slots(true)))
	column.add_child(Style.button("Load Game",func(): show_slots(false)))
	column.add_child(Style.button("Settings",func(): show_settings()))
	column.add_child(Style.button("Main Menu",func(): show_return_confirmation()))

func _focus_resume(button: Button) -> void:
	if overlay.visible and is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()

func show_slots(save_mode: bool, notice: String = "") -> void:
	page = "slots"
	clear_content()
	column.add_child(Style.label("SAVE GAME" if save_mode else "LOAD GAME",38))
	if not notice.is_empty(): column.add_child(Style.label(notice,17))
	var first: Button
	for slot in range(1,SaveManager.SLOT_COUNT+1):
		var selected := slot
		var button: Button
		if save_mode:
			button = Style.button(SaveManager.slot_label(selected),func():
				var success: bool = SaveManager.save_game(world,selected)
				show_slots(true,"Saved to slot %d" % selected if success else "Save failed")
			)
		else:
			button = Style.button(SaveManager.slot_label(selected),func():
				close()
				SaveManager.start_loaded_game(selected)
			)
			button.disabled = SaveManager.read_slot(selected).is_empty()
		column.add_child(button)
		if first == null and not button.disabled: first = button
	var back := Style.button("Back",func(): show_main())
	column.add_child(back)
	_focus_resume.call_deferred(first if first else back)

func show_settings() -> void:
	page = "settings"
	clear_content()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470,minf(590.0,get_viewport().get_visible_rect().size.y - 110.0))
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var settings := SettingsPanel.new()
	settings.back_requested.connect(show_main)
	scroll.add_child(settings)
	column.add_child(scroll)
	settings.focus_first_control.call_deferred()

func show_return_confirmation() -> void:
	page = "confirm"
	clear_content()
	column.add_child(Style.label("RETURN TO MAIN MENU?",31))
	column.add_child(Style.label("Unsaved progress will be lost.",17))
	var confirm := Style.button("Return without Saving",func():
		close()
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	)
	column.add_child(confirm)
	_focus_resume.call_deferred(confirm)
	column.add_child(Style.button("Cancel",func(): show_main()))
