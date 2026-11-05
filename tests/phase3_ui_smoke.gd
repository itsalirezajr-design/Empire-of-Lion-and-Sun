extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed: PackedScene = load("res://scenes/MainMenu.tscn")
	assert(packed != null, "Main menu scene could not be loaded")
	var menu: Control = packed.instantiate()
	root.add_child(menu)
	await process_frame
	var root_panel: PanelContainer = menu.get("root_panel")
	var settings_panel: PanelContainer = menu.get("settings_panel")
	assert(root_panel != null and root_panel.visible, "Main menu panel is not visible")
	assert(settings_panel != null and not settings_panel.visible, "Settings panel should start hidden")
	var menu_buttons := _find_buttons(root_panel)
	assert(menu_buttons.has("NEW CAMPAIGN"), "New campaign action is missing")
	assert(menu_buttons.has("CONTINUE"), "Continue action is missing")
	assert(menu_buttons.has("HOW TO PLAY"), "Tutorial action is missing")
	assert(menu_buttons.has("SETTINGS"), "Settings action is missing")
	menu.call("_show_settings")
	assert(settings_panel.visible, "Settings panel did not open")
	assert(_find_buttons(settings_panel).has("BACK"), "Settings back action is missing")
	menu.call("_show_tutorial")
	assert(_find_buttons(settings_panel).has("BACK"), "Tutorial back action is missing")
	menu.queue_free()
	print("PASS: phase 3 main menu, continue/new campaign, settings, tutorial navigation")
	quit()


func _find_buttons(node: Node) -> Array[String]:
	var found: Array[String] = []
	if node is Button:
		found.append((node as Button).text)
	for child in node.get_children():
		found.append_array(_find_buttons(child))
	return found
