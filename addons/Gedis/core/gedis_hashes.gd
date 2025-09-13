extends RefCounted
class_name GedisHashes

var _gedis: Gedis

func _init(gedis: Gedis):
	_gedis = gedis

# ------
# Hashes
# ------
func hset(key: String, field: String, value) -> int:
	_gedis._core._touch_type(key, _gedis._core._hashes)
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	var existed := int(d.has(field))
	d[field] = value
	_gedis._core._hashes[key] = d
	return 1 - existed

func hget(key: String, field: String, default_value: Variant = null):
	if _gedis._expiry._is_expired(key):
		return default_value
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	return d.get(field, default_value)

func hdel(key: String, fields) -> int:
	# Accept single field (String) or Array of fields
	if _gedis._expiry._is_expired(key):
		return 0
	if not _gedis._core._hashes.has(key):
		return 0
	var d: Dictionary = _gedis._core._hashes[key]
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
		_gedis._core._hashes.erase(key)
	else:
		_gedis._core._hashes[key] = d
	return removed

func hgetall(key: String) -> Dictionary:
	if _gedis._expiry._is_expired(key):
		return {}
	return _gedis._core._hashes.get(key, {}).duplicate(true)

func hexists(key: String, field: String) -> bool:
	if _gedis._expiry._is_expired(key):
		return false
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	return d.has(field)

func hkeys(key: String) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	return _gedis._core._hashes.get(key, {}).keys()

func hvals(key: String) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	return _gedis._core._hashes.get(key, {}).values()

func hlen(key: String) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	return _gedis._core._hashes.get(key, {}).size()