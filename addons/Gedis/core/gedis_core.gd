class_name GedisCore

# Core data buckets
var _store: Dictionary = {}
var _hashes: Dictionary = {}
var _lists: Dictionary = {}
var _sets: Dictionary = {}
var _sorted_sets: Dictionary = {}
var _expiry: Dictionary = {}

# Unified key→bucket index for O(1) lookups
# Maps key -> the Dictionary bucket it belongs to
var _key_index: Dictionary = {}

# Pub/Sub registries
var _subscribers: Dictionary[String, Array] = {}
var _psubscribers: Dictionary[String, Array] = {}
var _gedis: Gedis

func _init(gedis_instance: Gedis) -> void:
	_gedis = gedis_instance

func _now() -> int:
	return _gedis._time_source.get_time()

func _delete_all_types_for_key(key: String) -> void:
	if _key_index.has(key):
		var bucket: Dictionary = _key_index[key]
		bucket.erase(key)
		_key_index.erase(key)
	_expiry.erase(key)

func _touch_type(key: String, type_bucket: Dictionary) -> void:
	# When a key is used for a new type, remove it from other types.
	if _key_index.has(key):
		var existing_bucket: Dictionary = _key_index[key]
		if existing_bucket == type_bucket:
			return  # Key already in correct bucket
		existing_bucket.erase(key)
	_key_index[key] = type_bucket

func key_exists(key: String) -> bool:
	return _key_index.has(key)

func _get_all_keys() -> Dictionary[String, bool]:
	var all: Dictionary[String, bool] = {}
	for k in _key_index:
		all[str(k)] = true
	return all

func flushall() -> void:
	_store.clear()
	_hashes.clear()
	_lists.clear()
	_sets.clear()
	_sorted_sets.clear()
	_expiry.clear()
	_key_index.clear()
	_subscribers.clear()
	_psubscribers.clear()
	_gedis._pubsub._pattern_regex.clear()
	_gedis._expiry._expiry_list.clear()


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

	# Rebuild key index
	_rebuild_key_index()

	# Discard expired keys
	var now: float = _now()
	for key in _expiry.keys():
		if _expiry[key] < now:
			_delete_all_types_for_key(key)

	_gedis._expiry._rebuild_list()

func _rebuild_key_index() -> void:
	_key_index.clear()
	for k in _store:
		_key_index[k] = _store
	for k in _hashes:
		_key_index[k] = _hashes
	for k in _lists:
		_key_index[k] = _lists
	for k in _sets:
		_key_index[k] = _sets
	for k in _sorted_sets:
		_key_index[k] = _sorted_sets

func restore_key(key: String, data: Dictionary) -> void:
	_gedis._expiry._remove_key_from_list(key)
	_delete_all_types_for_key(key)
	var value = data["value"]
	var type = data["type"]

	if type == "string":
		_store[key] = value
		_key_index[key] = _store
	elif type == "hash":
		_hashes[key] = value
		_key_index[key] = _hashes
	elif type == "list":
		_lists[key] = value
		_key_index[key] = _lists
	elif type == "set":
		_sets[key] = value
		_key_index[key] = _sets
	elif type == "sorted_set":
		_sorted_sets[key] = value
		_key_index[key] = _sorted_sets

	if data.has("expiry"):
		_expiry[key] = data["expiry"]
		_gedis._expiry._add_key_to_list(key)
		
func rename(key: String, newkey: String) -> int:
	if not key_exists(key):
		return ERR_DOES_NOT_EXIST

	if key_exists(newkey):
		return 0

	var bucket: Dictionary = _key_index[key]
	bucket[newkey] = bucket[key]
	_key_index[newkey] = bucket

	if _expiry.has(key):
		_gedis._expiry._remove_key_from_list(key)
		var expiry_time = _expiry[key]
		_expiry[newkey] = expiry_time
		_gedis._expiry._add_key_to_list(newkey)

	_delete_all_types_for_key(key)
	return 1

func move(key: String, newkey: String) -> int:
	if not key_exists(key):
		return ERR_DOES_NOT_EXIST

	if key_exists(newkey):
		_delete_all_types_for_key(newkey)

	var bucket: Dictionary = _key_index[key]
	bucket[newkey] = bucket[key]
	_key_index[newkey] = bucket

	if _expiry.has(key):
		_gedis._expiry._remove_key_from_list(key)
		var expiry_time = _expiry[key]
		_expiry[newkey] = expiry_time
		_gedis._expiry._add_key_to_list(newkey)

	_delete_all_types_for_key(key)
	return 1

func ks(key: String) -> String:
	return "gedis:keyspace:" + key
	
func rks(key: String) -> String:
	var prefix = "gedis:keyspace:"
	if key.begins_with(prefix):
		return key.substr(prefix.length())
	else:
		return key
