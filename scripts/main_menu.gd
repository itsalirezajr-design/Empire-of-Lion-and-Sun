extends Control

const GAME_SCENE := "res://scenes/Main.tscn"
var root_panel: PanelContainer
var settings_panel: PanelContainer
var status_label: Label


func _ready() -> void:
	_build_menu()
	_show_main()


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.72, 0.58, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.055, 0.07)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	root_panel = PanelContainer.new()
	root_panel.custom_minimum_size = Vector2(420, 0)
	root_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.10, 0.12)))
	center.add_child(root_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	root_panel.add_child(layout)

	var emblem := Label.new()
	emblem.text = "☼"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size", 54)
	emblem.add_theme_color_override("font_color", Color(0.88, 0.69, 0.30))
	layout.add_child(emblem)

	var title := Label.new()
	title.text = "EMPIRE OF\nLION AND SUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "REAL-TIME STRATEGY  •  2026"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.63, 0.72, 0.74))
	layout.add_child(subtitle)

	_add_button(layout, "NEW CAMPAIGN", _start_new_game)
	_add_button(layout, "CONTINUE", _continue_game)
	_add_button(layout, "HOW TO PLAY", _show_tutorial)
	_add_button(layout, "SETTINGS", _show_settings)
	_add_button(layout, "EXIT", _exit_game)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.48))
	layout.add_child(status_label)

	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.custom_minimum_size = Vector2(420, 0)
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.10, 0.12)))
	center.add_child(settings_panel)


func _add_button(parent: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _show_main() -> void:
	root_panel.visible = true
	settings_panel.visible = false
	status_label.text = "Build your base. Train your forces. Defeat the enemy command center."


func _show_settings() -> void:
	root_panel.visible = false
	settings_panel.visible = true
	for child in settings_panel.get_children():
		child.queue_free()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	settings_panel.add_child(layout)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	layout.add_child(heading)

	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = float(config.get_value("audio", "master_volume", 0.8))
	var volume_label := Label.new()
	volume_label.text = "MASTER VOLUME  %d%%" % roundi(volume.value * 100.0)
	layout.add_child(volume_label)
	layout.add_child(volume)
	volume.value_changed.connect(func(value: float) -> void:
		AudioServer.set_bus_volume_linear(0, value)
		volume_label.text = "MASTER VOLUME  %d%%" % roundi(value * 100.0)
		config.set_value("audio", "master_volume", value)
		config.save("user://settings.cfg")
	)

	var fullscreen := CheckButton.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.button_pressed = bool(config.get_value("display", "fullscreen", true))
	layout.add_child(fullscreen)
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
		config.set_value("display", "fullscreen", enabled)
		config.save("user://settings.cfg")
	)

	_add_button(layout, "BACK", _show_main)


func _show_tutorial() -> void:
	root_panel.visible = false
	settings_panel.visible = true
	for child in settings_panel.get_children():
		child.queue_free()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	settings_panel.add_child(layout)
	var heading := Label.new()
	heading.text = "COMMANDER'S FIELD GUIDE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 23)
	layout.add_child(heading)
	var guide := Label.new()
	guide.text = "1. Tap a friendly unit to select it; drag on empty ground to select a group.\n\n2. Tap the battlefield to move selected forces. Two fingers pan and pinch to zoom.\n\n3. Build a barracks for infantry, a factory for tanks/APCs, and a depot for more storage.\n\n4. Select a building to repair or upgrade it. Production queues run automatically.\n\n5. Save often. Destroy the red enemy command center to win."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 16)
	layout.add_child(guide)
	_add_button(layout, "BACK", _show_main)


func _start_new_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _continue_game() -> void:
	if not FileAccess.file_exists("user://empire_save.json"):
		status_label.text = "No saved campaign found on this device."
		return
	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error == OK:
		get_tree().set_meta("load_saved_campaign", true)


func _exit_game() -> void:
	get_tree().quit()
