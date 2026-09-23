extends CanvasLayer
const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
var overlay: Control
var column: VBoxContainer
var previous_mouse_mode: Input.MouseMode
var previous_hud_visible := true
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	clear_content()
	column.add_child(Style.label("PAUSED",46))
	column.add_child(Style.button("Resume",func(): close()))
	column.add_child(Style.button("Save Game",func(): show_slots(true)))
	column.add_child(Style.button("Load Game",func(): show_slots(false)))
	column.add_child(Style.button("Settings",func(): show_settings()))
	column.add_child(Style.button("Main Menu",func(): show_return_confirmation()))

func show_slots(save_mode: bool, notice: String = "") -> void:
	clear_content()
	column.add_child(Style.label("SAVE GAME" if save_mode else "LOAD GAME",38))
	if not notice.is_empty(): column.add_child(Style.label(notice,17))
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
	column.add_child(Style.button("Back",func(): show_main()))

func show_settings() -> void:
	clear_content()
	var settings := SettingsPanel.new()
	settings.back_requested.connect(show_main)
	column.add_child(settings)

func show_return_confirmation() -> void:
	clear_content()
	column.add_child(Style.label("RETURN TO MAIN MENU?",31))
	column.add_child(Style.label("Unsaved progress will be lost.",17))
	column.add_child(Style.button("Return without Saving",func():
		close()
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	))
	column.add_child(Style.button("Cancel",func(): show_main()))
