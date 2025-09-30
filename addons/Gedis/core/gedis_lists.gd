extends RefCounted
class_name GedisLists

var _gedis

func _init(gedis):
	_gedis = gedis

# -----
# Lists
# -----
func lpush(key: String, value) -> int:
	_gedis._core._touch_type(key, _gedis._core._lists)
	var a: Array = _gedis._core._lists.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		a = value + a
	else:
		a.insert(0, value)
	_gedis._core._lists[key] = a
	_gedis.publish("gedis:keyspace:" + key, "set")
	return a.size()

func rpush(key: String, value) -> int:
	_gedis._core._touch_type(key, _gedis._core._lists)
	var a: Array = _gedis._core._lists.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		a += value
	else:
		a.append(value)
	_gedis._core._lists[key] = a
	_gedis.publish("gedis:keyspace:" + key, "set")
	return a.size()

func lpop(key: String):
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._lists.has(key):
		return null
	var a: Array = _gedis._core._lists[key].duplicate()
	if a.is_empty():
		return null
	var v = a.pop_front()
	if a.is_empty():
		_gedis._core._lists.erase(key)
		_gedis.publish("gedis:keyspace:" + key, "del")
	else:
		_gedis._core._lists[key] = a
		_gedis.publish("gedis:keyspace:" + key, "set")
	return v

func rpop(key: String):
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._lists.has(key):
		return null
	var a: Array = _gedis._core._lists[key].duplicate()
	if a.is_empty():
		return null
	var v = a.pop_back()
	if a.is_empty():
		_gedis._core._lists.erase(key)
		_gedis.publish("gedis:keyspace:" + key, "del")
	else:
		_gedis._core._lists[key] = a
		_gedis.publish("gedis:keyspace:" + key, "set")
	return v

func llen(key: String) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	var a: Array = _gedis._core._lists.get(key, [])
	return a.size()

func lexists(key: String) -> bool:
	if _gedis._expiry._is_expired(key):
		return false
	return _gedis._core._lists.has(key)

func lget(key: String) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	return _gedis._core._lists.get(key, []).duplicate()

func lrange(key: String, start: int, stop: int) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	var a: Array = _gedis._core._lists.get(key, [])
	var n = a.size()
	# normalize negative indices
	if start < 0:
		start = n + start
	if stop < 0:
		stop = n + stop
	# clamp
	start = max(0, start)
	stop = min(n - 1, stop)
	if start > stop or n == 0:
		return []
	var out: Array = []
	for i in range(start, stop + 1):
		out.append(a[i])
	return out

func lindex(key: String, index: int):
	if _gedis._expiry._is_expired(key):
		return null
	var a: Array = _gedis._core._lists.get(key, [])
	var n = a.size()
	if n == 0:
		return null
	if index < 0:
		index = n + index
	if index < 0 or index >= n:
		return null
	return a[index]

func lset(key: String, index: int, value) -> bool:
	if _gedis._expiry._is_expired(key):
		return false
	if not _gedis._core._lists.has(key):
		return false
	var a: Array = _gedis._core._lists[key].duplicate()
	var n = a.size()
	if index < 0:
		index = n + index
	if index < 0 or index >= n:
		return false
	a[index] = value
	_gedis._core._lists[key] = a
	_gedis.publish("gedis:keyspace:" + key, "set")
	return true

func lrem(key: String, count: int, value) -> int:
	# Remove elements equal to value. Behavior similar to Redis.
	if _gedis._expiry._is_expired(key):
		return 0
	if not _gedis._core._lists.has(key):
		return 0
	var a: Array = _gedis._core._lists[key].duplicate()
	var removed = 0
	if count == 0:
		# remove all
		var filtered: Array = []
		for v in a:
			if v == value:
				removed += 1
			else:
				filtered.append(v)
		a = filtered
	elif count > 0:
		var out: Array = []
		for v in a:
			if v == value and removed < count:
				removed += 1
				continue
			out.append(v)
		a = out
	else:
		# count < 0, remove from tail
		var rev = a.duplicate()
		rev.reverse()
		var out2: Array = []
		for v in rev:
			if v == value and removed < abs(count):
				removed += 1
				continue
			out2.append(v)
		out2.reverse()
		a = out2
	if a.is_empty():
		_gedis._core._lists.erase(key)
		_gedis.publish("gedis:keyspace:" + key, "del")
	else:
		_gedis._core._lists[key] = a
		_gedis.publish("gedis:keyspace:" + key, "set")
	return removed

func lmove(source: String, destination: String, from: String, to: String):
	if _gedis._expiry._is_expired(source):
		return null
	if not _gedis._core._lists.has(source):
		return null

	var source_list: Array = _gedis._core._lists[source]
	if source_list.is_empty():
		return null

	var element
	if from.to_upper() == "LEFT":
		element = source_list.pop_front()
	elif from.to_upper() == "RIGHT":
		element = source_list.pop_back()
	else:
		return null

	_gedis._core._touch_type(destination, _gedis._core._lists)
	var dest_list: Array = _gedis._core._lists.get(destination, [])

	if to.to_upper() == "LEFT":
		dest_list.insert(0, element)
	elif to.to_upper() == "RIGHT":
		dest_list.append(element)
	else:
		# Invalid 'to', restore source list and return error
		if from.to_upper() == "LEFT":
			source_list.insert(0, element)
		else:
			source_list.append(element)
		return null

	if source_list.is_empty():
		_gedis._core._lists.erase(source)
		_gedis.publish("gedis:keyspace:" + source, "del")
	else:
		_gedis._core._lists[source] = source_list
		_gedis.publish("gedis:keyspace:" + source, "set")
	_gedis._core._lists[destination] = dest_list
	_gedis.publish("gedis:keyspace:" + destination, "set")

	return element
# Trims a list to the specified range of indices.
# Removes all elements from the list that are not in the range [start, stop].
# If start is greater than stop, or start is out of bounds, the list will be emptied.
# ---
# @param key: The key of the list to trim.
# @param start: The starting index of the range.
# @param stop: The ending index of the range.
# @return: Returns true if the list was trimmed, false otherwise.
func ltrim(key: String, start: int, stop: int) -> bool:
	if _gedis._expiry._is_expired(key):
		return false
	if not _gedis._core._lists.has(key):
		return false

	var a: Array = _gedis._core._lists[key].duplicate()
	var n = a.size()

	if start < 0:
		start = n + start
	if stop < 0:
		stop = n + stop

	start = max(0, start)
	stop = min(n - 1, stop)

	if start > stop:
		_gedis._core._lists.erase(key)
		_gedis.publish("gedis:keyspace:" + key, "del")
		return true

	var trimmed_list: Array = []
	for i in range(start, stop + 1):
		trimmed_list.append(a[i])
	
	_gedis._core._lists[key] = trimmed_list
	_gedis.publish("gedis:keyspace:" + key, "set")
	return true

# Inserts a value into a list before or after a pivot value.
# ---
# @param key: The key of the list.
# @param position: "BEFORE" or "AFTER" the pivot.
# @param pivot: The value to insert the new value next to.
# @param value: The value to insert.
# @return: The new size of the list, or -1 if the pivot was not found. Returns 0 if the key does not exist or the position is invalid.
func linsert(key: String, position: String, pivot: Variant, value: Variant) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	if not _gedis._core._lists.has(key):
		return 0

	var a: Array = _gedis._core._lists[key].duplicate()
	var n = a.size()
	var index = -1

	for i in range(n):
		if a[i] == pivot:
			index = i
			break
	
	if index == -1:
		return -1

	if position.to_upper() == "BEFORE":
		a.insert(index, value)
	elif position.to_upper() == "AFTER":
		a.insert(index + 1, value)
	else:
		return 0
	
	_gedis._core._lists[key] = a
	_gedis.publish("gedis:keyspace:" + key, "set")
	return a.size()