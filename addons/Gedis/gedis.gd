extends Node
class_name Gedis

signal pubsub_message(channel, message)
signal psub_message(pattern, channel, message)

# Core data buckets
var _store: Dictionary = {}
var _hashes: Dictionary = {}
var _lists: Dictionary = {}
var _sets: Dictionary = {}
var _expiry: Dictionary = {} # key -> float (unix seconds)

# Pub/Sub registries
var _subscribers: Dictionary = {} # channel -> Array of Objects
var _psubscribers: Dictionary = {} # pattern -> Array of Objects

# Instance registry (simple JS-like static)
static var _instances: Array = []
static var _next_instance_id: int = 0
var _instance_id: int = -1
var _instance_name: String = ""

static var _debugger_registered = false

func _init() -> void:
	# assign id and register
	_instance_id = _next_instance_id
	_next_instance_id += 1
	_instance_name = "Gedis_%d" % _instance_id
	_instances.append(self)
	_ensure_debugger_is_registered()

func _ready() -> void:
	set_process(true)

func _exit_tree() -> void:
	# unregister instance
	for i in range(_instances.size()):
		if _instances[i] == self:
			_instances.remove_at(i)
			break

func _process(_delta: float) -> void:
	_purge_expired()

static func _ensure_debugger_is_registered():
	if Engine.is_editor_hint():
		return
	
	if not _debugger_registered:
		if Engine.has_singleton("EngineDebugger"):
			var debugger = Engine.get_singleton("EngineDebugger")
			debugger.register_message_capture("gedis", Callable(Gedis, "_on_debugger_message"))
			if debugger.is_active():
				debugger.send_message("gedis:ping", [])
			_debugger_registered = true

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
			for inst in _instances:
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

func _now() -> float:
	return Time.get_unix_time_from_system()

func _is_expired(key: String) -> bool:
	if _expiry.has(key) and _expiry[key] <= _now():
		_delete_all_types_for_key(key)
		return true
	return false

func _purge_expired() -> void:
	var to_remove: Array = []
	for key in _expiry.keys():
		if _expiry[key] <= _now():
			to_remove.append(key)
	for k in to_remove:
		_delete_all_types_for_key(k)

func _delete_all_types_for_key(key: String) -> void:
	_store.erase(key)
	_hashes.erase(key)
	_lists.erase(key)
	_sets.erase(key)
	_expiry.erase(key)

func _touch_type(key: String, type_bucket: Dictionary) -> void:
	# When a key is used for a new type, remove it from other types.
	if not type_bucket.has(key):
		_store.erase(key)
		_hashes.erase(key)
		_lists.erase(key)
		_sets.erase(key)

# -----------------
# String/number API
# -----------------
func set_value(key: StringName, value: Variant) -> void:
	_touch_type(str(key), _store)
	_store[str(key)] = value

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	if _is_expired(str(key)):
		return default_value
	return _store.get(str(key), default_value)

# del: accept String or Array of keys
func del(keys) -> int:
	if typeof(keys) == TYPE_ARRAY:
		var count = 0
		for k in keys:
			if _is_expired(str(k)):
				continue
			if exists(str(k)):
				_delete_all_types_for_key(str(k))
				count += 1
		return count
	else:
		var k = str(keys)
		var existed := int(exists(k))
		_delete_all_types_for_key(k)
		return existed

# exists: if Array -> return number of existing keys, else boolean for single key
func exists(keys) -> Variant:
	_purge_expired()
	if typeof(keys) == TYPE_ARRAY:
		var cnt = 0
		for k in keys:
			if not _is_expired(str(k)) and (_store.has(str(k)) or _hashes.has(str(k)) or _lists.has(str(k)) or _sets.has(str(k))):
				cnt += 1
		return cnt
	else:
		var k = str(keys)
		if _is_expired(k):
			return false
		return _store.has(k) or _hashes.has(k) or _lists.has(k) or _sets.has(k)

# key_exists: explicit single-key boolean (keeps parity with C++ API)
func key_exists(key: String) -> bool:
	return bool(exists(key))

func incr(key: String, amount: int = 1) -> int:
	var k := str(key)
	var current: int = 0
	if _is_expired(k):
		current = 0
	else:
		var raw = get_value(k, 0)
		match typeof(raw):
			TYPE_NIL:
				current = 0
			TYPE_INT:
				current = int(raw)
			TYPE_FLOAT:
				current = int(raw)
			TYPE_STRING:
				var s := str(raw).strip_edges()
				if s.find(".") != -1:
					current = int(float(s))
				else:
					# int(s) will raise on invalid strings; rely on Godot to convert or raise as needed.
					current = int(s)
			_:
				current = int(raw)
	var v: int = current + int(amount)
	# Store as an integer to keep types consistent
	_touch_type(k, _store)
	_store[k] = v
	return v

func decr(key: String, amount: int = 1) -> int:
	return incr(key, -int(amount))

func keys(pattern: String = "*") -> Array:
	var all: Dictionary = {}
	for k in _store.keys():
		all[str(k)] = true
	for k in _hashes.keys():
		all[str(k)] = true
	for k in _lists.keys():
		all[str(k)] = true
	for k in _sets.keys():
		all[str(k)] = true
	var rx := _glob_to_regex(pattern)
	var out: Array = []
	for k in all.keys():
		if not _is_expired(str(k)) and rx.search(str(k)) != null:
			out.append(str(k))
	return out

func mset(dict: Dictionary) -> void:
	for k in dict.keys():
		set_value(str(k), dict[k])

func mget(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append(get_value(str(k), null))
	return out

# Debugger-like helpers: type/dump/snapshot
func type(key: String) -> String:
	if _is_expired(key):
		return "none"
	if _store.has(key):
		return "string"
	if _hashes.has(key):
		return "hash"
	if _lists.has(key):
		return "list"
	if _sets.has(key):
		return "set"
	return "none"

func dump(key: String) -> Dictionary:
	var t = type(key)
	if t == "none":
		return {}
	var d: Dictionary = {}
	d["type"] = t
	match t:
		"string":
			d["value"] = _store.get(key, null)
		"hash":
			d["value"] = _hashes.get(key, {}).duplicate(true)
		"list":
			d["value"] = _lists.get(key, []).duplicate()
		"set":
			d["value"] = _sets.get(key, {}).keys()
		_:
			d["value"] = null
	return d

func snapshot(pattern: String = "*") -> Dictionary:
	var out: Dictionary = {}
	for k in keys(pattern):
		var key_data = dump(str(k))
		key_data["ttl"] = ttl(str(k))
		out[str(k)] = key_data
	return out

# ----------------
# Expiry commands
# ----------------
func expire(key: String, seconds: int) -> bool:
	if not exists(key):
		return false
	_expiry[key] = _now() + float(seconds)
	return true

# TTL returns:
# -2 if the key does not exist
# -1 if the key exists but has no associated expire
# >= 0 number of seconds to expire
func ttl(key: String) -> int:
	if not exists(key):
		return -2
	if not _expiry.has(key):
		return -1
	return max(0, int(ceil(_expiry[key] - _now())))

func persist(key: String) -> bool:
	if not exists(key):
		return false
	if _expiry.has(key):
		_expiry.erase(key)
		return true
	return false

# ------
# Hashes
# ------
func hset(key: String, field: String, value) -> int:
	_touch_type(key, _hashes)
	var d: Dictionary = _hashes.get(key, {})
	var existed := int(d.has(field))
	d[field] = value
	_hashes[key] = d
	return 1 - existed

func hget(key: String, field: String, default_value: Variant = null):
	if _is_expired(key):
		return default_value
	var d: Dictionary = _hashes.get(key, {})
	return d.get(field, default_value)

func hdel(key: String, fields) -> int:
	# Accept single field (String) or Array of fields
	if _is_expired(key):
		return 0
	if not _hashes.has(key):
		return 0
	var d: Dictionary = _hashes[key]
	var removed = 0
	if typeof(fields) == TYPE_ARRAY:
		for f in fields:
			if d.has(str(f)):
				d.erase(str(f))
				removed += 1
	else:
		var f = str(fields)
		if d.has(f):
			d.erase(f)
			removed = 1
	if d.is_empty():
		_hashes.erase(key)
	else:
		_hashes[key] = d
	return removed

func hgetall(key: String) -> Dictionary:
	if _is_expired(key):
		return {}
	return _hashes.get(key, {}).duplicate(true)

func hexists(key: String, field: String) -> bool:
	if _is_expired(key):
		return false
	var d: Dictionary = _hashes.get(key, {})
	return d.has(field)

func hkeys(key: String) -> Array:
	if _is_expired(key):
		return []
	return _hashes.get(key, {}).keys()

func hvals(key: String) -> Array:
	if _is_expired(key):
		return []
	return _hashes.get(key, {}).values()

func hlen(key: String) -> int:
	if _is_expired(key):
		return 0
	return _hashes.get(key, {}).size()

# -----
# Lists
# -----
func lpush(key: String, value) -> int:
	_touch_type(key, _lists)
	var a: Array = _lists.get(key, [])
	a.insert(0, value)
	_lists[key] = a
	return a.size()

func rpush(key: String, value) -> int:
	_touch_type(key, _lists)
	var a: Array = _lists.get(key, [])
	a.append(value)
	_lists[key] = a
	return a.size()

func lpop(key: String):
	if _is_expired(key):
		return null
	if not _lists.has(key):
		return null
	var a: Array = _lists[key]
	if a.is_empty():
		return null
	var v = a.pop_front()
	_lists[key] = a
	return v

func rpop(key: String):
	if _is_expired(key):
		return null
	if not _lists.has(key):
		return null
	var a: Array = _lists[key]
	if a.is_empty():
		return null
	var v = a.pop_back()
	_lists[key] = a
	return v

func llen(key: String) -> int:
	if _is_expired(key):
		return 0
	var a: Array = _lists.get(key, [])
	return a.size()

func lrange(key: String, start: int, stop: int) -> Array:
	if _is_expired(key):
		return []
	var a: Array = _lists.get(key, [])
	var n = a.size()
	# normalize negative indices
	if start < 0:
		start = n + start
	if stop < 0:
		stop = n + stop
	# clamp
	start = max(0, start)
	stop = min(n - 1, stop)
	if start > stop or n == 0:
		return []
	var out: Array = []
	for i in range(start, stop + 1):
		out.append(a[i])
	return out

func lindex(key: String, index: int):
	if _is_expired(key):
		return null
	var a: Array = _lists.get(key, [])
	var n = a.size()
	if n == 0:
		return null
	if index < 0:
		index = n + index
	if index < 0 or index >= n:
		return null
	return a[index]

func lset(key: String, index: int, value) -> bool:
	if _is_expired(key):
		return false
	if not _lists.has(key):
		return false
	var a: Array = _lists[key]
	var n = a.size()
	if index < 0:
		index = n + index
	if index < 0 or index >= n:
		return false
	a[index] = value
	_lists[key] = a
	return true

func lrem(key: String, count: int, value) -> int:
	# Remove elements equal to value. Behavior similar to Redis.
	if _is_expired(key):
		return 0
	if not _lists.has(key):
		return 0
	var a: Array = _lists[key].duplicate()
	var removed = 0
	if count == 0:
		# remove all
		var filtered: Array = []
		for v in a:
			if v == value:
				removed += 1
			else:
				filtered.append(v)
		a = filtered
	elif count > 0:
		var out: Array = []
		for v in a:
			if v == value and removed < count:
				removed += 1
				continue
			out.append(v)
		a = out
	else:
		# count < 0, remove from tail
		var rev = a.duplicate()
		rev.reverse()
		var out2: Array = []
		for v in rev:
			if v == value and removed < abs(count):
				removed += 1
				continue
			out2.append(v)
		out2.reverse()
		a = out2
	if a.is_empty():
		_lists.erase(key)
	else:
		_lists[key] = a
	return removed

# ----
# Sets
# ----
func sadd(key: String, member) -> int:
	_touch_type(key, _sets)
	var s: Dictionary = _sets.get(key, {})
	var existed := int(s.has(member))
	s[member] = true
	_sets[key] = s
	return 1 - existed

func srem(key: String, member) -> int:
	if _is_expired(key):
		return 0
	if not _sets.has(key):
		return 0
	var s: Dictionary = _sets[key]
	var existed := int(s.has(member))
	s.erase(member)
	if s.is_empty():
		_sets.erase(key)
	else:
		_sets[key] = s
	return existed

func smembers(key: String) -> Array:
	if _is_expired(key):
		return []
	var s: Dictionary = _sets.get(key, {})
	return s.keys()

func sismember(key: String, member) -> bool:
	if _is_expired(key):
		return false
	var s: Dictionary = _sets.get(key, {})
	return s.has(member)

func scard(key: String) -> int:
	if _is_expired(key):
		return 0
	return _sets.get(key, {}).size()

func spop(key: String):
	if _is_expired(key):
		return null
	if not _sets.has(key):
		return null
	var s: Dictionary = _sets[key]
	var keys_arr: Array = s.keys()
	if keys_arr.is_empty():
		return null
	var idx = randi() % keys_arr.size()
	var member = keys_arr[idx]
	s.erase(member)
	if s.is_empty():
		_sets.erase(key)
	else:
		_sets[key] = s
	return member

func smove(source: String, destination: String, member) -> bool:
	if _is_expired(source):
		return false
	if not sismember(source, member):
		return false
	# remove from source
	srem(source, member)
	# add to destination (creates destination set)
	sadd(destination, member)
	return true

# --------
# Pub/Sub
# --------
func publish(channel: String, message) -> void:
	# Backwards-compatible delivery:
	# 1) If subscriber objects registered via subscribe/psubscribe expect direct signals,
	#    call their 'pubsub_message'/'psub_message' on the subscriber object.
	# 2) Emit a single Gedis-level signal so external code can connect to this Gedis instance.
	# This avoids emitting the same Gedis signal multiple times (which would cause duplicate callbacks).
	# Direct subscribers (back-compat)
	if _subscribers.has(channel):
		for subscriber in _subscribers[channel]:
			if is_instance_valid(subscriber):
				# deliver directly to subscriber object if it exposes the signal
				if subscriber.has_signal("pubsub_message"):
					subscriber.emit_signal("pubsub_message", channel, message)
	# Emit a single Gedis-level pubsub notification for all listeners connected to this Gedis instance.
	if _subscribers.has(channel) and _subscribers[channel].size() > 0:
		emit_signal("pubsub_message", channel, message)
	# Pattern subscribers (back-compat + Gedis-level)
	for pattern in _psubscribers.keys():
		# Use simple glob matching: convert to RegEx
		var rx = _glob_to_regex(pattern)
		if rx.search(channel) != null:
			for subscriber in _psubscribers[pattern]:
				if is_instance_valid(subscriber):
					if subscriber.has_signal("psub_message"):
						subscriber.emit_signal("psub_message", pattern, channel, message)
			# Emit one Gedis-level pattern message for this matching pattern
			emit_signal("psub_message", pattern, channel, message)

func subscribe(channel: String, subscriber: Object) -> void:
	var arr: Array = _subscribers.get(channel, [])
	# avoid duplicates
	for s in arr:
		if s == subscriber:
			return
	arr.append(subscriber)
	_subscribers[channel] = arr

func unsubscribe(channel: String, subscriber: Object) -> void:
	if not _subscribers.has(channel):
		return
	var arr: Array = _subscribers[channel]
	for i in range(arr.size()):
		if arr[i] == subscriber:
			arr.remove_at(i)
			break
	if arr.is_empty():
		_subscribers.erase(channel)
	else:
		_subscribers[channel] = arr

func psubscribe(pattern: String, subscriber: Object) -> void:
	var arr: Array = _psubscribers.get(pattern, [])
	for s in arr:
		if s == subscriber:
			return
	arr.append(subscriber)
	_psubscribers[pattern] = arr

func punsubscribe(pattern: String, subscriber: Object) -> void:
	if not _psubscribers.has(pattern):
		return
	var arr: Array = _psubscribers[pattern]
	for i in range(arr.size()):
		if arr[i] == subscriber:
			arr.remove_at(i)
			break
	if arr.is_empty():
		_psubscribers.erase(pattern)
	else:
		_psubscribers[pattern] = arr

# ------
# Admin
# ------
func flushall() -> void:
	_store.clear()
	_hashes.clear()
	_lists.clear()
	_sets.clear()
	_expiry.clear()
	_subscribers.clear()
	_psubscribers.clear()

# ----------------
# Instance helpers
# ----------------
func set_instance_name(name: String) -> void:
	_instance_name = name

func get_instance_name() -> String:
	return _instance_name

static func get_all_instances() -> Array:
	var result: Array = []
	for inst in _instances:
		if is_instance_valid(inst):
			var info: Dictionary = {}
			info["id"] = inst._instance_id
			info["name"] = inst.name if inst.name else inst._instance_name
			info["object"] = inst
			result.append(info)
	return result

# ----------------
# Utility functions
# ----------------
func _glob_to_regex(glob: String) -> RegEx:
	var escaped := ""
	for ch in glob:
		match ch:
			".":
				escaped += "\\."
			"*":
				escaped += ".*"
			"?":
				escaped += "."
			"+":
				escaped += "\\+"
			"(":
				escaped += "\\("
			")":
				escaped += "\\)"
			"[":
				escaped += "\\["
			"]":
				escaped += "\\]"
			"^":
				escaped += "\\^"
			"$":
				escaped += "\\$"
			"|":
				escaped += "\\|"
			"\\":
				escaped += "\\\\"
			_:
				escaped += ch
	var r := RegEx.new()
	r.compile("^%s$" % escaped)
	return r
