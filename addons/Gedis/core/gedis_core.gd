class_name GedisCore

# Core data buckets
var _store: Dictionary = {}
var _hashes: Dictionary = {}
var _lists: Dictionary = {}
var _sets: Dictionary = {}
var _sorted_sets: Dictionary = {}
var _expiry: Dictionary = {} # key -> float (unix seconds)

# Pub/Sub registries
var _subscribers: Dictionary = {} # channel -> Array of Objects
var _psubscribers: Dictionary = {} # pattern -> Array of Objects

func _delete_all_types_for_key(key: String) -> void:
	_store.erase(key)
	_hashes.erase(key)
	_lists.erase(key)
	_sets.erase(key)
	_sorted_sets.erase(key)
	_expiry.erase(key)

func _touch_type(key: String, type_bucket: Dictionary) -> void:
	# When a key is used for a new type, remove it from other types.
	if not type_bucket.has(key):
		_store.erase(key)
		_hashes.erase(key)
		_lists.erase(key)
		_sets.erase(key)
		_sorted_sets.erase(key)

func key_exists(key: String) -> bool:
	return _store.has(key) or _hashes.has(key) or _lists.has(key) or _sets.has(key) or _sorted_sets.has(key)

func _get_all_keys() -> Dictionary:
	var all: Dictionary = {}
	for k in _store.keys():
		all[str(k)] = true
	for k in _hashes.keys():
		all[str(k)] = true
	for k in _lists.keys():
		all[str(k)] = true
	for k in _sets.keys():
		all[str(k)] = true
	for k in _sorted_sets.keys():
		all[str(k)] = true
	return all

func flushall() -> void:
	_store.clear()
	_hashes.clear()
	_lists.clear()
	_sets.clear()
	_sorted_sets.clear()
	_expiry.clear()
	_subscribers.clear()
	_psubscribers.clear()