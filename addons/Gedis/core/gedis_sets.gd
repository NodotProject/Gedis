extends RefCounted
class_name GedisSets

var _gedis: Gedis

func _init(gedis: Gedis):
	_gedis = gedis

# ----
# Sets
# ----
func sadd(key: String, member) -> int:
	_gedis._core._touch_type(key, _gedis._core._sets)
	var s: Dictionary = _gedis._core._sets.get(key, {})
	var existed := int(s.has(member))
	s[member] = true
	_gedis._core._sets[key] = s
	return 1 - existed

func srem(key: String, member) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	if not _gedis._core._sets.has(key):
		return 0
	var s: Dictionary = _gedis._core._sets[key]
	var existed := int(s.has(member))
	s.erase(member)
	if s.is_empty():
		_gedis._core._sets.erase(key)
	else:
		_gedis._core._sets[key] = s
	return existed

func smembers(key: String) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	var s: Dictionary = _gedis._core._sets.get(key, {})
	return s.keys()

func sismember(key: String, member) -> bool:
	if _gedis._expiry._is_expired(key):
		return false
	var s: Dictionary = _gedis._core._sets.get(key, {})
	return s.has(member)

func scard(key: String) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	return _gedis._core._sets.get(key, {}).size()

func spop(key: String):
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._sets.has(key):
		return null
	var s: Dictionary = _gedis._core._sets[key]
	var keys_arr: Array = s.keys()
	if keys_arr.is_empty():
		return null
	var idx = randi() % keys_arr.size()
	var member = keys_arr[idx]
	s.erase(member)
	if s.is_empty():
		_gedis._core._sets.erase(key)
	else:
		_gedis._core._sets[key] = s
	return member

func smove(source: String, destination: String, member) -> bool:
	if _gedis._expiry._is_expired(source):
		return false
	if not sismember(source, member):
		return false
	# remove from source
	srem(source, member)
	# add to destination (creates destination set)
	sadd(destination, member)
	return true