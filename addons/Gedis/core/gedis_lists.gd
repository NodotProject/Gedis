extends RefCounted
class_name GedisLists

var _gedis: Gedis

func _init(gedis: Gedis):
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
	return a.size()

func rpush(key: String, value) -> int:
	_gedis._core._touch_type(key, _gedis._core._lists)
	var a: Array = _gedis._core._lists.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		a += value
	else:
		a.append(value)
	_gedis._core._lists[key] = a
	return a.size()

func lpop(key: String):
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._lists.has(key):
		return null
	var a: Array = _gedis._core._lists[key]
	if a.is_empty():
		return null
	var v = a.pop_front()
	_gedis._core._lists[key] = a
	return v

func rpop(key: String):
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._lists.has(key):
		return null
	var a: Array = _gedis._core._lists[key]
	if a.is_empty():
		return null
	var v = a.pop_back()
	_gedis._core._lists[key] = a
	return v

func llen(key: String) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	var a: Array = _gedis._core._lists.get(key, [])
	return a.size()

func lget(key: String) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	return _gedis._core._lists.get(key, [])

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
	var a: Array = _gedis._core._lists[key]
	var n = a.size()
	if index < 0:
		index = n + index
	if index < 0 or index >= n:
		return false
	a[index] = value
	_gedis._core._lists[key] = a
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
	else:
		_gedis._core._lists[key] = a
	return removed