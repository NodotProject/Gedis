@tool
extends EditorPlugin

const GedisDebuggerPanel = preload("res://addons/Gedis/debugger/gedis_debugger_panel.tscn")

class GedisDebuggerPlugin extends EditorDebuggerPlugin:
	var dashboard_tabs = {} # session_id -> dashboard_control
	var full_snapshot_data = {} # session_id -> full_snapshot_data
	var pending_requests = {} # session_id -> { "command": String, "instance_id": int, "context": any }
	var _pubsub_events = {} # session_id -> []
	
	func _has_capture(capture):
		return capture == "gedis"
	
	func _capture(message, data, session_id):
		if not _pubsub_events.has(session_id):
			_pubsub_events[session_id] = []
		# message is the full message string received by the editor (e.g. "gedis:instances_data")
		# data is the Array payload sent from the game. Engines and editors may wrap values
		# differently (sometimes the payload is passed as a single element array), so normalize.
		var parts = message.split(":")
		var kind = parts[1] if parts.size() > 1 else ""
		
		match kind:
			"ping":
				_request_instances_update(session_id)
				return true
			"instances_data":
				# instances may be either sent as the array itself or wrapped as [instances]
				var instances = data
				if data.size() == 1 and typeof(data[0]) == TYPE_ARRAY:
					instances = data[0]
				_update_instances(instances, session_id)
				return true
			"snapshot_data":
				# snapshot is expected to be a Dictionary; it may be wrapped in an Array
				var snapshot = data[0] if data.size() > 0 else {}
				_update_snapshot_data(snapshot, session_id)
				return true
			"key_value_data":
				# key/value payload may be wrapped similarly
				var kv = data[0] if data.size() > 0 else {}
				_update_key_value_data(kv, session_id)
				return true
			"pubsub_data":
				var channels_data = data[0] if data.size() > 0 else {}
				var patterns_data = data[1] if data.size() > 1 else {}
				_update_pubsub_tree(session_id, channels_data, patterns_data)
				return true
			"pubsub_event":
				if not session_id in _pubsub_events:
					_pubsub_events[session_id] = []
				_pubsub_events[session_id].append({"message": data[0], "data": [data[1], data[2]]})
				_populate_pubsub_events(session_id)
				_fetch_pubsub_for_selected_instance(session_id) # Refresh tree on event
				return true
		return false

	func _setup_session(session_id):
		var dashboard = GedisDebuggerPanel.instantiate()
		dashboard.name = "Gedis"
		dashboard.plugin = self
		
		var session = get_session(session_id)
		session.started.connect(func(): _on_session_started(session_id))
		session.stopped.connect(func(): _on_session_stopped(session_id))
		session.add_session_tab(dashboard)
		
		dashboard_tabs[session_id] = dashboard
		_pubsub_events[session_id] = []

	func _on_session_started(session_id):
		full_snapshot_data[session_id] = {}
		_clear_views(session_id)
		_populate_pubsub_events(session_id)
		_update_pubsub_tree(session_id, {}, {})
		
		var dashboard = dashboard_tabs[session_id]
		
		var instance_selector = dashboard.find_child("instance_selector", true, false)
		if instance_selector:
			instance_selector.item_selected.connect(func(index): _on_instance_selected(index, session_id))
		
		var refresh_button = dashboard.find_child("RefreshButton", true, false)
		if refresh_button:
			refresh_button.pressed.connect(func(): _request_instances_update(session_id))
		
		var fetch_keys_button = dashboard.find_child("FetchKeysButton", true, false)
		if fetch_keys_button:
			fetch_keys_button.pressed.connect(func(): _fetch_keys_for_selected_instance(session_id))
		
		var filter_button = dashboard.find_child("filter_button", true, false)
		if filter_button:
			filter_button.pressed.connect(func(): _on_filter_pressed(session_id))
		
		var key_list = dashboard.find_child("key_list", true, false)
		if key_list:
			key_list.item_selected.connect(func(): _on_key_selected(session_id))
		
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
				var name = instance_info.get("name", "Gedis_%d" % instance_info.get("id", -1))
				var id = int(instance_info["id"]) if instance_info.has("id") else -1
				instance_selector.add_item(name, id)
			
			if instance_selector.get_item_count() > 0:
				instance_selector.select(0)
				# The select() method does not trigger the item_selected signal, so we must call the handler manually.
				_fetch_keys_for_selected_instance(session_id)
				_fetch_pubsub_for_selected_instance(session_id)
		else:
			status_label.text = "No Gedis instances found in running game"
			status_label.add_theme_color_override("font_color", Color.ORANGE)
			_clear_views(session_id)
	
	func _on_instance_selected(_index, session_id):
		_fetch_keys_for_selected_instance(session_id)
		_fetch_pubsub_for_selected_instance(session_id)

	func _fetch_keys_for_selected_instance(session_id):
		if not session_id in dashboard_tabs:
			return

		var dashboard = dashboard_tabs[session_id]
		var instance_selector = dashboard.find_child("instance_selector", true, false)
		if not instance_selector or instance_selector.get_selected() < 0:
			return

		var instance_id = instance_selector.get_item_id(instance_selector.get_selected())
		var session = get_session(session_id)
		pending_requests[session_id] = {"command": "snapshot", "instance_id": instance_id}
		if session and session.is_active():
			session.send_message("gedis:request_instance_data", [instance_id, "snapshot", "*"])

	func _fetch_pubsub_for_selected_instance(session_id):
		if not session_id in dashboard_tabs:
			return

		var dashboard = dashboard_tabs[session_id]
		var instance_selector = dashboard.find_child("instance_selector", true, false)
		if not instance_selector or instance_selector.get_selected() < 0:
			return

		var instance_id = instance_selector.get_item_id(instance_selector.get_selected())
		var session = get_session(session_id)
		pending_requests[session_id] = {"command": "pubsub", "instance_id": instance_id}
		if session and session.is_active():
			session.send_message("gedis:request_instance_data", [instance_id, "pubsub"])

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
			regex.compile(pattern)

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
			var instance_selector = dashboard.find_child("instance_selector", true, false)
			
			if not key_list or not key_value_view or not instance_selector:
				return
			
			var selected_item = key_list.get_selected()
			if not selected_item:
				key_value_view.text = ""
				return
			
			var selected_key = selected_item.get_text(0)
			if instance_selector.get_selected() >= 0:
				var instance_id = instance_selector.get_item_id(instance_selector.get_selected())
				var session = get_session(session_id)
				pending_requests[session_id] = {"command": "dump", "instance_id": instance_id, "key": selected_key}
				if session and session.is_active():
					session.send_message("gedis:request_instance_data", [instance_id, "dump", selected_key])
			
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

	func _populate_pubsub_events(session_id):
		var dashboard = dashboard_tabs[session_id]
		var events_tree = dashboard.find_child("PubSubEventsTree", true, false)
		if not events_tree:
			return
		events_tree.clear()
		var root = events_tree.create_item()
		for event in _pubsub_events.get(session_id, []):
			var event_item = events_tree.create_item(root)
			event_item.set_text(0, event.message)
			event_item.set_text(1, JSON.stringify(event.data))

	func _update_pubsub_tree(session_id, channels_data, patterns_data):
		var dashboard = dashboard_tabs[session_id]
		var pub_sub_tree = dashboard.find_child("PubSubTree", true, false)
		if not pub_sub_tree:
			return

		pub_sub_tree.clear()
		var root = pub_sub_tree.create_item()

		var channels_item = pub_sub_tree.create_item(root)
		channels_item.set_text(0, "Channels")
		for channel_name in channels_data:
			var subscribers = channels_data[channel_name]
			var channel_item = pub_sub_tree.create_item(channels_item)
			channel_item.set_text(0, channel_name)
			for sub in subscribers:
				var sub_item = pub_sub_tree.create_item(channel_item)
				sub_item.set_text(0, str(sub))

		var patterns_item = pub_sub_tree.create_item(root)
		patterns_item.set_text(0, "Patterns")
		for pattern_name in patterns_data:
			var subscribers = patterns_data[pattern_name]
			var pattern_item = pub_sub_tree.create_item(patterns_item)
			pattern_item.set_text(0, pattern_name)
			for sub in subscribers:
				var sub_item = pub_sub_tree.create_item(pattern_item)
				sub_item.set_text(0, str(sub))

	func send_message_to_game(message: String, data: Array):
		var session_id = get_current_session_id()
		if session_id != -1:
			var session = get_session(session_id)
			if session and session.is_active():
				session.send_message("gedis:" + message, data)

	func get_current_session_id():
		for session_id in dashboard_tabs:
			var session = get_session(session_id)
			if session and session.is_active():
				return session_id
		return -1

var debugger_plugin

func _enter_tree():
	debugger_plugin = GedisDebuggerPlugin.new()
	add_debugger_plugin(debugger_plugin)

func _exit_tree():
	remove_debugger_plugin(debugger_plugin)
	debugger_plugin = null
