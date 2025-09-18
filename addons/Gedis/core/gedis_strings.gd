extends RefCounted
class_name GedisStrings

var _gedis: Gedis

func _init(gedis: Gedis):
	_gedis = gedis

# -----------------
# String/number API
# -----------------
func set_value(key: StringName, value: Variant) -> void:
	_gedis._core._touch_type(str(key), _gedis._core._store)
	_gedis._core._store[str(key)] = value
	_gedis.publish("gedis:keyspace:" + str(key), "set")

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	if _gedis._expiry._is_expired(str(key)):
		return default_value
	return _gedis._core._store.get(str(key), default_value)

# del: accept String or Array of keys
func del(keys) -> int:
	if typeof(keys) == TYPE_ARRAY:
		var count = 0
		for k in keys:
			if _gedis._expiry._is_expired(str(k)):
				continue
			if exists(str(k)):
				_gedis.publish("gedis:keyspace:" + str(k), "del")
				_gedis._core._delete_all_types_for_key(str(k))
				count += 1
		return count
	else:
		var k = str(keys)
		var existed := int(exists(k))
		if existed > 0:
			_gedis.publish("gedis:keyspace:" + k, "del")
		_gedis._core._delete_all_types_for_key(k)
		return existed

# exists: if Array -> return number of existing keys, else boolean for single key
func exists(keys) -> Variant:
	if typeof(keys) == TYPE_ARRAY:
		var cnt = 0
		for k in keys:
			if not _gedis._expiry._is_expired(str(k)) and _gedis._core.key_exists(str(k)):
				cnt += 1
		return cnt
	else:
		var k = str(keys)
		if _gedis._expiry._is_expired(k):
			return false
		return _gedis._core.key_exists(k)

# key_exists: explicit single-key boolean (keeps parity with C++ API)
func key_exists(key: String) -> bool:
	return bool(exists(key))

func incrby(key: String, amount: int = 1) -> int:
	var k := str(key)
	var current: int = 0
	if _gedis._expiry._is_expired(k):
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
	_gedis._core._touch_type(k, _gedis._core._store)
	_gedis._core._store[k] = v
	_gedis.publish("gedis:keyspace:" + k, "set")
	return v

func decrby(key: String, amount: int = 1) -> int:
	return incrby(key, -int(amount))

func keys(pattern: String = "*") -> Array:
	var all: Dictionary = _gedis._core._get_all_keys()
	var rx := _gedis._utils._glob_to_regex(pattern)
	var out: Array = []
	for k in all.keys():
		if not _gedis._expiry._is_expired(str(k)) and rx.search(str(k)) != null:
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

func append(key: String, value: String) -> int:
	var k := str(key)
	var current_value := get_value(k, "")
	if typeof(current_value) != TYPE_STRING:
		current_value = str(current_value)
	var new_value: String = current_value + value
	set_value(k, new_value)
	return new_value.length()

func getset(key: String, value: Variant) -> Variant:
	var k := str(key)
	var old_value = get_value(k)
	set_value(k, value)
	return old_value

func strlen(key: String) -> int:
	var k := str(key)
	var value = get_value(k)
	if typeof(value) == TYPE_STRING:
		return value.length()
	return 0

func setnx(key: String, value: Variant) -> int:
	var k := str(key)
	if not _gedis._expiry._is_expired(k) and key_exists(k):
		return 0
	set_value(k, value)
	return 1