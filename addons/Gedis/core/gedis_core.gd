class_name GedisCore

# Core data buckets
var _store: Dictionary = {}
var _hashes: Dictionary = {}
var _lists: Dictionary = {}
var _sets: Dictionary = {}
var _sorted_sets: Dictionary = {}
var _expiry: Dictionary[String, float] = {}

# Pub/Sub registries
var _subscribers: Dictionary[String, Array] = {}
var _psubscribers: Dictionary[String, Array] = {}
var _gedis: Gedis

func _init(gedis_instance: Gedis) -> void:
	_gedis = gedis_instance

func _now() -> int:
	return _gedis._time_source.get_time()

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

func _get_all_keys() -> Dictionary[String, bool]:
	var all: Dictionary[String, bool] = {}
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


func dump_all(options: Dictionary = {}) -> Dictionary:
	var state := {
		"store": _store.duplicate(true),
		"hashes": _hashes.duplicate(true),
		"lists": _lists.duplicate(true),
		"sets": _sets.duplicate(true),
		"sorted_sets": _sorted_sets.duplicate(true),
		"expiry": _expiry.duplicate(true),
	}

	var include: Array = options.get("include", [])
	var exclude: Array = options.get("exclude", [])

	if not include.is_empty():
		for bucket_name in state:
			var bucket: Dictionary = state[bucket_name]
			for key in bucket.keys():
				var keep = false
				for prefix in include:
					if key.begins_with(prefix):
						keep = true
						break
				if not keep:
					bucket.erase(key)

	if not exclude.is_empty():
		for bucket_name in state:
			var bucket: Dictionary = state[bucket_name]
			for key in bucket.keys():
				for prefix in exclude:
					if key.begins_with(prefix):
						bucket.erase(key)
						break
	return state


func restore_all(state: Dictionary) -> void:
	flushall()

	_store = state.get("store", {})
	_hashes = state.get("hashes", {})
	_lists = state.get("lists", {})
	_sets = state.get("sets", {})
	_sorted_sets = state.get("sorted_sets", {})
	_expiry = state.get("expiry", {})

	# Discard expired keys
	var now: float = _now()
	for key in _expiry.keys():
		if _expiry[key] < now:
			_delete_all_types_for_key(key)

func restore_key(key: String, data: Dictionary) -> void:
	_delete_all_types_for_key(key)
	var value = data["value"]
	var type = data["type"]

	if type == "string":
		_store[key] = value
	elif type == "hash":
		_hashes[key] = value
	elif type == "list":
		_lists[key] = value
	elif type == "set":
		_sets[key] = value
	elif type == "sorted_set":
		_sorted_sets[key] = value
	
	if data.has("expiry"):
		_expiry[key] = data["expiry"]
		
func rename(key: String, newkey: String) -> int:
	if not key_exists(key):
		return ERR_DOES_NOT_EXIST

	if key_exists(newkey):
		return 0

	var value
	if _store.has(key):
		value = _store[key]
		_store[newkey] = value
	elif _hashes.has(key):
		value = _hashes[key]
		_hashes[newkey] = value
	elif _lists.has(key):
		value = _lists[key]
		_lists[newkey] = value
	elif _sets.has(key):
		value = _sets[key]
		_sets[newkey] = value
	elif _sorted_sets.has(key):
		value = _sorted_sets[key]
		_sorted_sets[newkey] = value
	else:
		return ERR_DOES_NOT_EXIST

	if _expiry.has(key):
		var expiry_time = _expiry[key]
		_expiry[newkey] = expiry_time

	_delete_all_types_for_key(key)
	return 1

func move(key: String, newkey: String) -> int:
	if not key_exists(key):
		return ERR_DOES_NOT_EXIST

	if key_exists(newkey):
		_delete_all_types_for_key(newkey)

	var value
	if _store.has(key):
		value = _store[key]
		_store[newkey] = value
	elif _hashes.has(key):
		value = _hashes[key]
		_hashes[newkey] = value
	elif _lists.has(key):
		value = _lists[key]
		_lists[newkey] = value
	elif _sets.has(key):
		value = _sets[key]
		_sets[newkey] = value
	elif _sorted_sets.has(key):
		value = _sorted_sets[key]
		_sorted_sets[newkey] = value
	else:
		return ERR_DOES_NOT_EXIST

	if _expiry.has(key):
		var expiry_time = _expiry[key]
		_expiry[newkey] = expiry_time

	_delete_all_types_for_key(key)
	return 1

func ks(key: String) -> String:
	return "gedis:keyspace:" + key
	
func rks(key: String) -> String:
	return key.substr("gedis:keyspace:".length())
