extends RefCounted
class_name GedisDebugger

var _gedis: Gedis

func _init(gedis: Gedis):
	_gedis = gedis

static func _ensure_debugger_is_registered():
	if Engine.is_editor_hint():
		return
	
	if not Gedis._debugger_registered:
		if Engine.has_singleton("EngineDebugger"):
			var debugger = Engine.get_singleton("EngineDebugger")
			debugger.register_message_capture("gedis", Callable(Gedis, "_on_debugger_message"))
			if debugger.is_active():
				debugger.send_message("gedis:ping", [])
			Gedis._debugger_registered = true

static func _on_debugger_message(message: String, data: Array) -> bool:
	# EngineDebugger will call this with the suffix (the part after "gedis:")
	# so message will be e.g. "request_instances" or "request_instance_data".
	if not Engine.has_singleton("EngineDebugger"):
		return false

	match message:
		"request_instances":
			var instances_data = []
			for instance_info in Gedis.get_all_instances():
				instances_data.append({
					"id": instance_info["id"],
					"name": instance_info["name"]
				})
			var debugger = Engine.get_singleton("EngineDebugger")
			if debugger and debugger.is_active():
				debugger.send_message("gedis:instances_data", instances_data)
			return true

		"request_instance_data":
			if data.size() < 2:
				return false
			var instance_id = data[0]
			var command = data[1]

			# Find the target instance in the static registry.
			var target_instance = null
			for inst in Gedis._instances:
				if is_instance_valid(inst) and inst._instance_id == instance_id:
					target_instance = inst
					break

			if target_instance == null:
				print("Gedis: target instance not found for id", instance_id)
				return false
			
			var debugger = Engine.get_singleton("EngineDebugger")
			if not debugger or not debugger.is_active():
				return false

			match command:
				"snapshot":
					var pattern = data[2] if data.size() > 2 else "*"
					var snapshot_data = target_instance.snapshot(pattern)
					debugger.send_message("gedis:snapshot_data", [snapshot_data])
					return true
				"dump":
					if data.size() < 3:
						return false
					var key = data[2]
					var key_value_data = target_instance.dump(key)
					debugger.send_message("gedis:key_value_data", [key_value_data])
					return true
				"set":
					if data.size() < 4:
						return false
					var key = data[2]
					var value = data[3]
					target_instance.set_value(key, value)
					var key_value_data = target_instance.dump(key)
					debugger.send_message("gedis:key_value_data", [key_value_data])
					return true

	return false

# Debugger-like helpers: type/dump/snapshot
func type(key: String) -> String:
	if _gedis._expiry._is_expired(key):
		return "none"
	if _gedis._core._store.has(key):
		return "string"
	if _gedis._core._hashes.has(key):
		return "hash"
	if _gedis._core._lists.has(key):
		return "list"
	if _gedis._core._sets.has(key):
		return "set"
	if _gedis._core._sorted_sets.has(key):
		return "sorted_set"
	return "none"

func dump(key: String) -> Dictionary:
	var t = type(key)
	if t == "none":
		return {}
	var d: Dictionary = {}
	d["type"] = t
	match t:
		"string":
			d["value"] = _gedis._core._store.get(key, null)
		"hash":
			d["value"] = _gedis._core._hashes.get(key, {}).duplicate(true)
		"list":
			d["value"] = _gedis._core._lists.get(key, []).duplicate()
		"set":
			d["value"] = _gedis._core._sets.get(key, {}).keys()
		"sorted_set":
			d["value"] = _gedis._core._sorted_sets.get(key, {}).duplicate(true)
		_:
			d["value"] = null
	return d

func snapshot(pattern: String = "*") -> Dictionary:
	var out: Dictionary = {}
	for k in _gedis._strings.keys(pattern):
		var key_data = dump(str(k))
		key_data["ttl"] = _gedis._expiry.ttl(str(k))
		out[str(k)] = key_data
	return out