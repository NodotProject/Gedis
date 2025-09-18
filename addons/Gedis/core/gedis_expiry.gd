extends RefCounted
class_name GedisExpiry

var _gedis: Gedis

func _init(p_gedis: Gedis):
	_gedis = p_gedis

func _now() -> int:
	return _gedis.get_time_source().get_time()

func _is_expired(key: String) -> bool:
	if _gedis._core._expiry.has(key) and _gedis._core._expiry[key] <= _now():
		_gedis._core._delete_all_types_for_key(key)
		return true
	return false

func _purge_expired() -> void:
	var to_remove: Array = []
	for key in _gedis._core._expiry.keys():
		if _gedis._core._expiry[key] <= _now():
			to_remove.append(key)
	for k in to_remove:
		_gedis.publish("gedis:keyspace:" + k, "expire")
		_gedis._core._delete_all_types_for_key(k)

# ----------------
# Expiry commands
# ----------------
func expire(key: String, seconds: int) -> bool:
	if not _gedis.exists(key):
		return false
	_gedis._core._expiry[key] = _now() + (float(seconds) * 1000.0)
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
		_gedis._core._expiry.erase(key)
		return true
	return false

func setex(key: String, seconds: int, value: Variant) -> void:
	_gedis.set_value(key, value)
	expire(key, seconds)