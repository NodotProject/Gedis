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

func sunion(keys: Array) -> Array:
	var result_set := {}
	for key in keys:
		var members = smembers(key)
		for member in members:
			result_set[member] = true
	return result_set.keys()

func sinter(keys: Array) -> Array:
	if keys.is_empty():
		return []
	
	var result_set := {}
	var first_set_members = smembers(keys[0])
	for member in first_set_members:
		result_set[member] = true

	for i in range(1, keys.size()):
		var next_set_members = smembers(keys[i])
		var current_members = result_set.keys()
		for member in current_members:
			if not next_set_members.has(member):
				result_set.erase(member)
	
	return result_set.keys()

func sdiff(keys: Array) -> Array:
	if keys.is_empty():
		return []

	var result_set := {}
	var first_set_members = smembers(keys[0])
	for member in first_set_members:
		result_set[member] = true

	for i in range(1, keys.size()):
		var next_set_members = smembers(keys[i])
		for member in next_set_members:
			if result_set.has(member):
				result_set.erase(member)

	return result_set.keys()

func sunionstore(destination: String, keys: Array) -> int:
	var result_members = sunion(keys)
	_gedis._core._sets.erase(destination)
	for member in result_members:
		sadd(destination, member)
	return result_members.size()

func sinterstore(destination: String, keys: Array) -> int:
	var result_members = sinter(keys)
	_gedis._core._sets.erase(destination)
	for member in result_members:
		sadd(destination, member)
	return result_members.size()

func sdiffstore(destination: String, keys: Array) -> int:
	var result_members = sdiff(keys)
	_gedis._core._sets.erase(destination)
	for member in result_members:
		sadd(destination, member)
	return result_members.size()

func srandmember(key: String, count: int = 1):
	if _gedis._expiry._is_expired(key):
		return null if count == 1 else []

	var s: Dictionary = _gedis._core._sets.get(key, {})
	var members = s.keys()
	if members.is_empty():
		return null if count == 1 else []

	if count == 1:
		return members.pick_random()

	var result = []
	if count > 0:
		# Positive count: return unique elements
		if count >= members.size():
			members.shuffle()
			return members
		
		var used_indices = {}
		while result.size() < count:
			var idx = randi() % members.size()
			if not used_indices.has(idx):
				result.append(members[idx])
				used_indices[idx] = true
	else: # count < 0
		# Negative count: repetitions are allowed
		var abs_count = abs(count)
		for _i in range(abs_count):
			result.append(members.pick_random())
			
	return result