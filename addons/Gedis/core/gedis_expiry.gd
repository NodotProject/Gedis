extends RefCounted
class_name GedisExpiry

var _gedis: Gedis

# Provides an ordered view of expirations for efficient purging.
# The list is sorted by timestamp and stores [timestamp, key] pairs.
var _expiry_list: Array

func _init(p_gedis: Gedis):
	_gedis = p_gedis
	_expiry_list = []

func _now() -> int:
	return _gedis._time_source.get_time()

func _is_expired(key: String) -> bool:
	if _gedis._core._expiry.has(key) and _gedis._core._expiry[key] <= _now():
		var timestamp = _gedis._core._expiry[key]
		_gedis._core._delete_all_types_for_key(key)
		var entry = [timestamp, key]
		var index = _expiry_list.bsearch(entry)
		if index < _expiry_list.size() and _expiry_list[index] == entry:
			_expiry_list.remove_at(index)
		return true
	return false

func _purge_expired() -> void:
	var now := _now()
	var expired_count := 0
	var ex := _gedis._core._expiry
	for item in _expiry_list:
		var timestamp: int = item[0]
		var key: String = item[1]

		if timestamp <= now:
			if ex.has(key) and ex[key] == timestamp:
				_gedis._core._delete_all_types_for_key(key)
				_gedis.publish("gedis:keyspace:" + key, "expire")
			expired_count += 1
		else:
			break

	if expired_count > 0:
		_expiry_list = _expiry_list.slice(expired_count)

# ----------------
# Expiry commands
# ----------------
func expire(key: String, seconds: int) -> bool:
	if not _gedis.exists(key):
		return false

	# If the key already has an expiry, remove the old entry from the sorted list.
	if _gedis._core._expiry.has(key):
		var old_timestamp = _gedis._core._expiry[key]
		var old_entry = [old_timestamp, key]
		var index = _expiry_list.bsearch(old_entry)
		if index < _expiry_list.size() and _expiry_list[index] == old_entry:
			_expiry_list.remove_at(index)

	var new_timestamp = _now() + (float(seconds) * 1000.0)
	_gedis._core._expiry[key] = new_timestamp

	# Add the new expiry to the sorted list.
	var new_entry = [new_timestamp, key]
	var insertion_index = _expiry_list.bsearch(new_entry)
	_expiry_list.insert(insertion_index, new_entry)

	return true

# TTL returns:
# -2 if the key does not exist
# -1 if the key exists but has no associated expire
# >= 0 number of seconds to expire
func ttl(key: String) -> int:
	if not _gedis.exists(key):
		return -2
	if not _gedis._core._expiry.has(key):
		return -1
	return max(0, int(ceil((_gedis._core._expiry[key] - _now()) / 1000.0)))

func persist(key: String) -> bool:
	if not _gedis.exists(key):
		return false
	if _gedis._core._expiry.has(key):
		var timestamp = _gedis._core._expiry[key]
		_gedis._core._expiry.erase(key)
		var entry = [timestamp, key]
		var index = _expiry_list.bsearch(entry)
		if index < _expiry_list.size() and _expiry_list[index] == entry:
			_expiry_list.remove_at(index)
		return true
	return false

func setex(key: String, seconds: int, value: Variant) -> void:
	_gedis.set_value(key, value)
	expire(key, seconds)