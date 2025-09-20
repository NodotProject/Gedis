extends RefCounted
class_name GedisHashes

var _gedis

func _init(gedis):
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
	_gedis.publish("gedis:keyspace:" + key, "set")
	return 1 - existed

func hget(key: String, field: String, default_value: Variant = null):
	if _gedis._expiry._is_expired(key):
		return default_value
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	return d.get(field, default_value)

# Gets the values of multiple fields in a hash.
# ---
# @param key: The key of the hash.
# @param fields: An array of fields to get the values of.
# @return: An array of values for the given fields. If a field does not exist, the corresponding value in the array will be null.
func hmget(key: String, fields: Array) -> Array:
	if _gedis._expiry._is_expired(key):
		return fields.map(func(_field): return null)
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	var result: Array = []
	for field in fields:
		result.append(d.get(field, null))
	return result

# Sets multiple fields and their values in a hash.
# ---
# @param key: The key of the hash.
# @param field_value_pairs: A dictionary of field-value pairs to set.
func hmset(key: String, field_value_pairs: Dictionary) -> void:
	_gedis._core._touch_type(key, _gedis._core._hashes)
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	for field in field_value_pairs:
		d[field] = field_value_pairs[field]
	_gedis._core._hashes[key] = d
	_gedis.publish("gedis:keyspace:" + key, "set")

func hincrby(key: String, field: String, amount: int) -> Variant:
	_gedis._core._touch_type(key, _gedis._core._hashes)
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	var value = d.get(field, 0)
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		push_error("WRONGTYPE Operation against a key holding the wrong kind of value")
		return null
	value += amount
	d[field] = value
	_gedis._core._hashes[key] = d
	_gedis.publish("gedis:keyspace:" + key, "set")
	return value

func hincrbyfloat(key: String, field: String, amount: float) -> Variant:
	_gedis._core._touch_type(key, _gedis._core._hashes)
	var d: Dictionary = _gedis._core._hashes.get(key, {})
	var value = d.get(field, 0.0)
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		push_error("WRONGTYPE Operation against a key holding the wrong kind of value")
		return null
	value += amount
	d[field] = value
	_gedis._core._hashes[key] = d
	_gedis.publish("gedis:keyspace:" + key, "set")
	return value

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
		_gedis.publish("gedis:keyspace:" + key, "del")
	else:
		_gedis._core._hashes[key] = d
	return removed

func hgetall(key: String) -> Dictionary:
	if _gedis._expiry._is_expired(key):
		return {}
	return _gedis._core._hashes.get(key, {}).duplicate(true)

func hexists(key: String, field = null) -> bool:
	if _gedis._expiry._is_expired(key):
		return false
	
	if field == null:
		return _gedis._core._hashes.has(key)

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