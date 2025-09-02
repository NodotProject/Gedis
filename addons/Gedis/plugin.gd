@tool
extends EditorPlugin

class GedisDebuggerPlugin extends EditorDebuggerPlugin:
	var dashboard_tabs = {} # session_id -> dashboard_control
	var full_snapshot_data = {} # session_id -> full_snapshot_data
	var pending_requests = {} # session_id -> { "command": String, "instance_id": int, "context": any }
	
	func _has_capture(capture):
		# Handle messages with the prefix "gedis:"
		return capture.begins_with("gedis:") or capture == "gedis"
		
	func _capture(message, data, session_id):
		match message:
			"gedis:instances_update":
				_update_instances(data, session_id)
				return true
			"gedis:snapshot_data":
				# Backend sends snapshot wrapped in an Array: [Dictionary]
				if typeof(data) == TYPE_ARRAY and data.size() > 0:
					_update_snapshot_data(data[0], session_id)
				else:
					_update_snapshot_data({}, session_id)
				return true
			"gedis:key_value_data":
				# Backend sends key/value wrapped in an Array: [Dictionary]
				if typeof(data) == TYPE_ARRAY and data.size() > 0:
					_update_key_value_data(data[0], session_id)
				else:
					_update_key_value_data({}, session_id)
				return true
			"gedis:instance_response":
				# Expected payloads:
				#  [ id, payload ] or [ id, command, payload ]
				if typeof(data) == TYPE_ARRAY and data.size() >= 3:
					var resp_id = data[0]
					var resp_command = data[1]
					var payload = data[2]
					
					if resp_command == "snapshot":
						_update_snapshot_data(payload, session_id)
					elif resp_command == "dump":
						_update_key_value_data(payload, session_id)
					elif resp_command == "keys":
						full_snapshot_data[session_id] = payload
						_populate_key_list(session_id)
					else:
						# Fallback: try to show as key/value
						_update_key_value_data(payload, session_id)
					
					pending_requests.erase(session_id)
				return true
		return false
	
	func _setup_session(session_id):
		# Create the dashboard UI for this session
		var dashboard = _create_dashboard_ui(session_id)
		dashboard.name = "Gedis Dashboard"
		
		var session = get_session(session_id)
		session.started.connect(func(): _on_session_started(session_id))
		session.stopped.connect(func(): _on_session_stopped(session_id))
		session.add_session_tab(dashboard)
		
		dashboard_tabs[session_id] = dashboard
	
	func _create_dashboard_ui(session_id):
		var dashboard = VBoxContainer.new()
		
		# Status label
		var status_label = Label.new()
		status_label.name = "status_label"
		status_label.text = "Waiting for game connection..."
		status_label.add_theme_color_override("font_color", Color.ORANGE)
		dashboard.add_child(status_label)
		
		# Top panel with instance selector and refresh
		var top_panel = HBoxContainer.new()
		dashboard.add_child(top_panel)
		
		var instance_selector = OptionButton.new()
		instance_selector.name = "instance_selector"
		instance_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_panel.add_child(instance_selector)
		instance_selector.item_selected.connect(func(index): _on_instance_selected(index, session_id))
		
		var refresh_button = Button.new()
		refresh_button.text = "Refresh Instances"
		top_panel.add_child(refresh_button)
		refresh_button.pressed.connect(func(): _request_instances_update(session_id))
		
		var fetch_keys_button = Button.new()
		fetch_keys_button.text = "Fetch Keys"
		top_panel.add_child(fetch_keys_button)
		fetch_keys_button.pressed.connect(func(): _on_fetch_keys_pressed(session_id))
		
		# Search box
		var search_panel = HBoxContainer.new()
		dashboard.add_child(search_panel)
		
		var search_box = LineEdit.new()
		search_box.name = "search_box"
		search_box.placeholder_text = "Filter keys..."
		search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_panel.add_child(search_box)
		
		var filter_button = Button.new()
		filter_button.name = "filter_button"
		filter_button.text = "Filter"
		search_panel.add_child(filter_button)
		filter_button.pressed.connect(func(): _on_filter_pressed(session_id))
		
		# Split container for key list and value view
		var h_split = HSplitContainer.new()
		h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dashboard.add_child(h_split)
		
		# Key list tree
		var key_list = Tree.new()
		key_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		key_list.name = "key_list"
		key_list.columns = 3
		key_list.column_titles_visible = true
		key_list.set_column_title(0, "Key")
		key_list.set_column_title(1, "Type")
		key_list.set_column_title(2, "TTL")
		h_split.add_child(key_list)
		key_list.item_selected.connect(func(): _on_key_selected(session_id))
		
		# Value view
		var key_value_view = TextEdit.new()
		key_value_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_value_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		key_value_view.name = "key_value_view"
		key_value_view.editable = false
		h_split.add_child(key_value_view)
		
		# TODO: Fix edit and save functionality
		# Bottom panel with edit/save buttons
		#var bottom_panel = HBoxContainer.new()
		#dashboard.add_child(bottom_panel)
		#
		#var edit_button = Button.new()
		#edit_button.name = "edit_button"
		#edit_button.text = "Edit"
		#edit_button.disabled = true
		#bottom_panel.add_child(edit_button)
		#edit_button.pressed.connect(func(): _on_edit_pressed(session_id))
		#
		#var save_button = Button.new()
		#save_button.name = "save_button"
		#save_button.text = "Save"
		#save_button.disabled = true
		#bottom_panel.add_child(save_button)
		#save_button.pressed.connect(func(): _on_save_pressed(session_id))
		
		return dashboard
	
	func _on_session_started(session_id):
		_request_instances_update(session_id)
	
	func _on_session_stopped(session_id):
		if session_id in dashboard_tabs:
			var dashboard = dashboard_tabs[session_id]
			var status_label = dashboard.find_child("status_label", true, false)
			if status_label:
				status_label.text = "Game disconnected"
				status_label.add_theme_color_override("font_color", Color.RED)
	
	func _request_instances_update(session_id):
			var session = get_session(session_id)
			if session and session.is_active():
				session.send_message("gedis:request_instances", [])
	
	func _update_instances(instances_data, session_id):
		if not session_id in dashboard_tabs:
			return
		
		var dashboard = dashboard_tabs[session_id]
		var status_label = dashboard.find_child("status_label", true, false)
		var instance_selector = dashboard.find_child("instance_selector", true, false)
		
		if not instance_selector:
			print("Warning: instance_selector not found in dashboard")
			return
		
		instance_selector.clear()
		
		if instances_data.size() > 0:
			status_label.text = "Connected - Found %d Gedis instance(s)" % instances_data.size()
			status_label.add_theme_color_override("font_color", Color.GREEN)
			
			for instance_info in instances_data:
				var name = instance_info["name"] if instance_info.has("name") else str(instance_info)
				var id = int(instance_info["id"]) if instance_info.has("id") else -1
				instance_selector.add_item(name, id)
			
			if instance_selector.get_item_count() > 0:
				instance_selector.select(0)
				# Manually select an instance to fetch keys
		else:
			status_label.text = "No Gedis instances found in running game"
			status_label.add_theme_color_override("font_color", Color.ORANGE)
			_clear_views(session_id)
	
	func _on_instance_selected(index, session_id):
			if not session_id in dashboard_tabs:
				return
			
			var dashboard = dashboard_tabs[session_id]
			var instance_selector = dashboard.find_child("instance_selector", true, false)
			var search_box = dashboard.find_child("search_box", true, false)
			
			if instance_selector and index >= 0 and index < instance_selector.get_item_count():
				var instance_id = instance_selector.get_item_id(index)
				var session = get_session(session_id)
				# Request snapshot via debugger RPC instead of trying to resolve native object
				pending_requests[session_id] = {"command": "snapshot", "instance_id": instance_id}
				if session and session.is_active():
					session.send_message("gedis:request_instance_data", [instance_id, "snapshot", "*"])
	
	func _on_fetch_keys_pressed(session_id):
			# Manual fetch triggered by the "Fetch Keys" button.
			var dashboard = dashboard_tabs[session_id]
			var instance_selector = dashboard.find_child("instance_selector", true, false)
			var selected_index = instance_selector.get_selected()
			
			var instance_id = instance_selector.get_item_id(selected_index)
			var session = get_session(session_id)
			pending_requests[session_id] = {"command": "snapshot", "instance_id": instance_id}
			if session and session.is_active():
				session.send_message("gedis:request_instance_data", [instance_id, "snapshot", "*"])

	func _on_filter_pressed(session_id):
		if not session_id in dashboard_tabs:
			return
		
		var dashboard = dashboard_tabs[session_id]
		var search_box = dashboard.find_child("search_box", true, false)
		var filter_text = search_box.text if search_box else ""
		
		_populate_key_list(session_id, filter_text)
	
	
	func _update_snapshot_data(snapshot_data, session_id):
		if not session_id in dashboard_tabs:
			return
		
		full_snapshot_data[session_id] = snapshot_data
		_populate_key_list(session_id)

	func _populate_key_list(session_id, filter_text = ""):
		var dashboard = dashboard_tabs[session_id]
		var key_list = dashboard.find_child("key_list", true, false)
		
		if not key_list:
			return
		
		key_list.clear()
		var root = key_list.create_item()
		
		var data_to_display = full_snapshot_data.get(session_id, {})
		
		var regex = RegEx.new()
		if not filter_text.is_empty():
			var pattern = filter_text.replace("*", ".*").replace("?", ".")
			regex.compile("^" + pattern + "$")

		for redis_key in data_to_display.keys():
			if filter_text.is_empty() or regex.search(redis_key):
				var key_info = data_to_display[redis_key]
				var item = key_list.create_item(root)
				item.set_text(0, redis_key)
				item.set_text(1, key_info.get("type", "UNKNOWN"))
				var ttl_value = key_info.get("ttl", -1)
				if ttl_value == -1:
					item.set_text(2, "∞")
				elif ttl_value == -2:
					item.set_text(2, "EXPIRED")
				else:
					item.set_text(2, str(ttl_value) + "s")
	
	func _update_key_value_data(key_value_data, session_id):
		if not session_id in dashboard_tabs:
			return
		
		var dashboard = dashboard_tabs[session_id]
		var key_value_view = dashboard.find_child("key_value_view", true, false)
		
		if not key_value_view:
			return
		
		if key_value_data is Dictionary and "value" in key_value_data:
			key_value_view.text = var_to_str(key_value_data.value)
		else:
			key_value_view.text = var_to_str(key_value_data)
	
	func _on_key_selected(session_id):
			if not session_id in dashboard_tabs:
				return
			
			var dashboard = dashboard_tabs[session_id]
			var key_list = dashboard.find_child("key_list", true, false)
			var key_value_view = dashboard.find_child("key_value_view", true, false)
			var edit_button = dashboard.find_child("edit_button", true, false)
			var save_button = dashboard.find_child("save_button", true, false)
			var instance_selector = dashboard.find_child("instance_selector", true, false)
			
			if not key_list or not key_value_view or not edit_button or not save_button or not instance_selector:
				return
			
			var selected_item = key_list.get_selected()
			if not selected_item:
				key_value_view.text = ""
				edit_button.disabled = true
				return
			
			var selected_key = selected_item.get_text(0)
			if instance_selector.get_selected() >= 0:
				var instance_id = instance_selector.get_item_id(instance_selector.get_selected())
				var session = get_session(session_id)
				pending_requests[session_id] = {"command": "dump", "instance_id": instance_id, "key": selected_key}
				if session and session.is_active():
					session.send_message("gedis:request_instance_data", [instance_id, "dump", selected_key])
			
			edit_button.disabled = false
			save_button.disabled = true
			key_value_view.editable = false
	
	
	func _on_edit_pressed(session_id):
		if not session_id in dashboard_tabs:
			return
		
		var dashboard = dashboard_tabs[session_id]
		var key_value_view = dashboard.find_child("key_value_view", true, false)
		var edit_button = dashboard.find_child("edit_button", true, false)
		var save_button = dashboard.find_child("save_button", true, false)
		
		if not key_value_view or not edit_button or not save_button:
			return
		
		key_value_view.editable = true
		save_button.disabled = false
		edit_button.disabled = true
	
	func _on_save_pressed(session_id):
		if not session_id in dashboard_tabs:
			return
		
		var dashboard = dashboard_tabs[session_id]
		var key_list = dashboard.find_child("key_list", true, false)
		var key_value_view = dashboard.find_child("key_value_view", true, false)
		var instance_selector = dashboard.find_child("instance_selector", true, false)
		var edit_button = dashboard.find_child("edit_button", true, false)
		var save_button = dashboard.find_child("save_button", true, false)
		
		if not key_list or not key_value_view or not instance_selector or not edit_button or not save_button:
			return
		
		var selected_item = key_list.get_selected()
		if not selected_item or instance_selector.get_selected() < 0:
			return
		
		var instance_id = instance_selector.get_item_id(instance_selector.get_selected())
		var key = selected_item.get_text(0)
		var new_value_text = key_value_view.text
		
		var json = JSON.new()
		var error = json.parse(new_value_text)
		var new_value
		if error == OK:
			new_value = json.get_data()
		else:
			# Fallback for non-JSON strings
			new_value = new_value_text

		var session = get_session(session_id)
		if session and session.is_active():
			pending_requests[session_id] = {"command": "set", "instance_id": instance_id, "key": key}
			session.send_message("gedis:request_instance_data", [instance_id, "set", key, new_value])

		key_value_view.editable = false
		save_button.disabled = true
		edit_button.disabled = false
	
	func _clear_views(session_id):
		if not session_id in dashboard_tabs:
			return
		
		var dashboard = dashboard_tabs[session_id]
		var key_list = dashboard.find_child("key_list", true, false)
		var key_value_view = dashboard.find_child("key_value_view", true, false)
		var edit_button = dashboard.find_child("edit_button", true, false)
		var save_button = dashboard.find_child("save_button", true, false)
		
		if key_list:
			key_list.clear()
		if key_value_view:
			key_value_view.text = ""
		if edit_button:
			edit_button.disabled = true
		if save_button:
			save_button.disabled = true

var debugger_plugin = GedisDebuggerPlugin.new()

func _enter_tree():
	add_debugger_plugin(debugger_plugin)

func _exit_tree():
	remove_debugger_plugin(debugger_plugin)
