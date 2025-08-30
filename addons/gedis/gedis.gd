extends Node
class_name Gedis

var _store: Dictionary = {}
var _hashes: Dictionary = {}
var _lists: Dictionary = {}
var _sets: Dictionary = {}
var _expiry: Dictionary = {} # key -> float (unix seconds)

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	_purge_expired()

func _now() -> float:
	return Time.get_unix_time_from_system()

func _is_expired(key: String) -> bool:
	if _expiry.has(key) and _expiry[key] <= _now():
		_delete_all_types_for_key(key)
		return true
	return false

func _purge_expired() -> void:
	var to_remove: Array[String] = []
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
func set(key: String, value) -> void:
	_touch_type(key, _store)
	_store[key] = value

func get(key: String, default_value := null):
	if _is_expired(key):
		return default_value
	return _store.get(key, default_value)

func del(key: String) -> int:
	var existed := int(exists(key))
	_delete_all_types_for_key(key)
	return existed

func exists(key: String) -> bool:
	if _is_expired(key):
		return false
	return _store.has(key) or _hashes.has(key) or _lists.has(key) or _sets.has(key)

func incr(key: String, amount: int = 1) -> int:
	var v: int = int(get(key, 0)) + amount
	set(key, v)
	return v

func decr(key: String, amount: int = 1) -> int:
	return incr(key, -amount)

func keys(pattern: String = "*") -> Array[String]:
	var all: Dictionary = {}
	for k in _store.keys():
		all[k] = true
	for k in _hashes.keys():
		all[k] = true
	for k in _lists.keys():
		all[k] = true
	for k in _sets.keys():
		all[k] = true
	var rx := _glob_to_regex(pattern)
	var out: Array[String] = []
	for k in all.keys():
		if not _is_expired(k) and rx.search(k) != -1:
			out.append(k)
	return out

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

# ------
# Hashes
# ------
func hset(key: String, field: String, value) -> void:
	_touch_type(key, _hashes)
	var d: Dictionary = _hashes.get(key, {})
	d[field] = value
	_hashes[key] = d

func hget(key: String, field: String, default_value := null):
	if _is_expired(key):
		return default_value
	var d: Dictionary = _hashes.get(key, {})
	return d.get(field, default_value)

func hdel(key: String, field: String) -> int:
	if _is_expired(key):
		return 0
	if not _hashes.has(key):
		return 0
	var d: Dictionary = _hashes[key]
	var existed := int(d.has(field))
	d.erase(field)
	if d.is_empty():
		_hashes.erase(key)
	else:
		_hashes[key] = d
	return existed

func hgetall(key: String) -> Dictionary:
	if _is_expired(key):
		return {}
	return _hashes.get(key, {}).duplicate(true)

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

# --------
# Expiry
# --------
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
	return _expiry.erase(key)

# ------
# Admin
# ------
func flushall() -> void:
	_store.clear()
	_hashes.clear()
	_lists.clear()
	_sets.clear()
	_expiry.clear()
