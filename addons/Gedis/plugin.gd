@tool
extends EditorPlugin

var dashboard
var instance_selector
var key_list
var key_value_view
var search_box
var edit_button
var save_button
var refresh_button
var selected_gedis = null
var selected_key = null

const PAGE_SIZE = 20
var current_page = 0

func _enter_tree():
	dashboard = VBoxContainer.new()
	dashboard.name = "GedisDashboard"

	var top_panel = HBoxContainer.new()
	dashboard.add_child(top_panel)

	instance_selector = OptionButton.new()
	instance_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_panel.add_child(instance_selector)
	instance_selector.item_selected.connect(_on_instance_selected)

	refresh_button = Button.new()
	refresh_button.text = "Refresh"
	top_panel.add_child(refresh_button)
	refresh_button.pressed.connect(_refresh_instances)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Search keys (e.g. user:*)"
	dashboard.add_child(search_box)
	search_box.text_changed.connect(_on_search_text_changed)

	var h_split = HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dashboard.add_child(h_split)

	key_list = Tree.new()
	key_list.columns = 3
	key_list.set_column_title(0, "Key")
	key_list.set_column_title(1, "Type")
	key_list.set_column_title(2, "TTL")
	h_split.add_child(key_list)
	key_list.item_selected.connect(_on_key_selected)

	key_value_view = TextEdit.new()
	key_value_view.editable = false
	h_split.add_child(key_value_view)

	var bottom_panel = HBoxContainer.new()
	dashboard.add_child(bottom_panel)

	edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.disabled = true
	bottom_panel.add_child(edit_button)
	edit_button.pressed.connect(_on_edit_pressed)

	save_button = Button.new()
	save_button.text = "Save"
	save_button.disabled = true
	bottom_panel.add_child(save_button)
	save_button.pressed.connect(_on_save_pressed)

	add_control_to_bottom_panel(dashboard, "Gedis Dashboard")
	_refresh_instances()

func _exit_tree():
	if dashboard:
		remove_control_from_bottom_panel(dashboard)
		dashboard.free()

func _refresh_instances():
	instance_selector.clear()
	var scene_root = get_tree().get_root()
	_find_gedis_nodes(scene_root)
	if instance_selector.get_item_count() > 0:
		_on_instance_selected(0)

func _find_gedis_nodes(node):
	if node is Gedis:
		instance_selector.add_item(node.name, node.get_path())
	for child in node.get_children():
		_find_gedis_nodes(child)

func _on_instance_selected(index):
	var path = instance_selector.get_item_metadata(index)
	selected_gedis = get_node(path)
	_load_keys()

func _load_keys(pattern = "*"):
	if not is_instance_valid(selected_gedis):
		return

	key_list.clear()
	var root = key_list.create_item()
	var keys = selected_gedis.snapshot(pattern, PAGE_SIZE, current_page * PAGE_SIZE)
	
	for key_data in keys:
		var item = key_list.create_item(root)
		item.set_text(0, key_data["key"])
		item.set_text(1, key_data["type"])
		item.set_text(2, str(key_data["ttl"]))

func _on_search_text_changed(new_text):
	current_page = 0
	if new_text.is_empty():
		_load_keys()
	else:
		_load_keys(new_text)

func _on_key_selected():
	var selected_item = key_list.get_selected()
	if not selected_item:
		selected_key = null
		key_value_view.text = ""
		edit_button.disabled = true
		return

	selected_key = selected_item.get_text(0)
	if not is_instance_valid(selected_gedis):
		return

	var data = selected_gedis.dump(selected_key)
	key_value_view.text = var_to_str(data)
	edit_button.disabled = false
	save_button.disabled = true
	key_value_view.editable = false

func _on_edit_pressed():
	key_value_view.editable = true
	save_button.disabled = false
	edit_button.disabled = true

func _on_save_pressed():
	if not is_instance_valid(selected_gedis) or selected_key == null:
		return

	var new_value_str = key_value_view.text
	var new_value = str_to_var(new_value_str)

	var key_type = selected_gedis.type(selected_key)

	match key_type:
		"string":
			selected_gedis.set(selected_key, new_value)
		"hash":
			if typeof(new_value) == TYPE_DICTIONARY:
				for field in new_value:
					selected_gedis.hset(selected_key, field, new_value[field])
		"list":
			if typeof(new_value) == TYPE_ARRAY:
				selected_gedis.lpush(selected_key, new_value)

	key_value_view.editable = false
	save_button.disabled = true
	edit_button.disabled = false
	_on_key_selected() # Refresh view
