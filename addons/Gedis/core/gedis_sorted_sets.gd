# This class provides a sorted set data structure, where each member is associated with a score.
# Members are stored in an array, sorted by score, allowing for efficient range queries. A dictionary
# is used for quick lookups of member scores.
#
# Features:
# - Add/update members with scores.
# - Remove members.
# - Retrieve members within a score range.
# - Pop members that are "ready" based on a timestamp score.
#
# The implementation aims to be simple and efficient for common use cases in game development,
# such as managing timed events, priority queues, or leaderboards.

extends RefCounted
class_name GedisSortedSets

var _gedis: Gedis

func _init(gedis: Gedis):
	_gedis = gedis

# Adds a new member to the sorted set with the specified score.
# If the member already exists, its score is updated, and its position in the set is adjusted.
#
# @param member: The member to add or update.
# @param score: The score associated with the member.
func add(key: String, member: String, score: int) -> int:
	_gedis._core._touch_type(key, _gedis._core._sorted_sets)
	var data: Dictionary = _gedis._core._sorted_sets.get(key, {
		"sorted_set": [],
		"member_scores": {}
	})

	var new_member = not data.member_scores.has(member)
	if not new_member:
		remove(key, member)
		data = _gedis._core._sorted_sets.get(key, {
			"sorted_set": [],
			"member_scores": {}
		})

	data.member_scores[member] = score
	var entry = [score, member]
	var inserted: bool = false
	for i in range(data.sorted_set.size()):
		if score < data.sorted_set[i][0]:
			data.sorted_set.insert(i, entry)
			inserted = true
			break
	if not inserted:
		data.sorted_set.append(entry)
	
	_gedis._core._sorted_sets[key] = data
	return 1 if new_member else 0


# Removes a member from the sorted set.
#
# @param member: The member to remove.
func remove(key: String, member: String) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	if not _gedis._core._sorted_sets.has(key):
		return 0
	
	var data: Dictionary = _gedis._core._sorted_sets[key]
	if not data.member_scores.has(member):
		return 0

	var score = data.member_scores[member]
	data.member_scores.erase(member)

	for i in range(data.sorted_set.size()):
		if data.sorted_set[i][0] == score and data.sorted_set[i][1] == member:
			data.sorted_set.remove_at(i)
			if data.sorted_set.is_empty():
				_gedis._core._sorted_sets.erase(key)
			else:
				_gedis._core._sorted_sets[key] = data
			return 1
	return 0


# Returns an array of members within the specified score range (inclusive).
#
# @param min_score: The minimum score of the range.
# @param max_score: The maximum score of the range.
# @param withscores: Whether to return scores along with members.
# @return: An array of members, or an array of [member, score] pairs if withscores is true.
func zrange(key: String, start: int, stop: int, withscores: bool = false) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	if not _gedis._core._sorted_sets.has(key):
		return []

	var data: Dictionary = _gedis._core._sorted_sets[key]
	var sorted_set: Array = data.sorted_set
	var set_len: int = sorted_set.size()

	var start_index: int = start
	if start_index < 0:
		start_index = set_len + start_index

	var stop_index: int = stop
	if stop_index < 0:
		stop_index = set_len + stop_index

	if start_index < 0:
		start_index = 0

	if stop_index >= set_len:
		stop_index = set_len - 1

	if start_index > stop_index or start_index >= set_len:
		return []

	var result: Array = []
	for i in range(start_index, stop_index + 1):
		var entry = sorted_set[i]
		var score = entry[0]
		var member = entry[1]
		if withscores:
			result.append(member)
			result.append(score)
		else:
			result.append(member)
	return result


# Returns a range of members from the sorted set, ordered by score in reverse.
#
# @param start: The starting index of the range.
# @param stop: The ending index of the range.
# @param withscores: Whether to return scores along with members.
# @return: An array of members, or an array of [member, score] pairs if withscores is true.
func zrevrange(key: String, start: int, stop: int, withscores: bool = false) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	if not _gedis._core._sorted_sets.has(key):
		return []

	var data: Dictionary = _gedis._core._sorted_sets[key]
	var sorted_set: Array = data.sorted_set.duplicate()
	sorted_set.reverse() # Order from high to low score

	var set_len: int = sorted_set.size()

	var start_index: int = start
	if start_index < 0:
		start_index = set_len + start_index

	var stop_index: int = stop
	if stop_index < 0:
		stop_index = set_len + stop_index

	if start_index < 0:
		start_index = 0

	if stop_index >= set_len:
		stop_index = set_len - 1

	if start_index > stop_index or start_index >= set_len:
		return []

	var result: Array = []
	for i in range(start_index, stop_index + 1):
		var entry = sorted_set[i]
		var score = entry[0]
		var member = entry[1]
		if withscores:
			result.append([member, score])
		else:
			result.append(member)
	return result


# Removes and returns members with scores up to the given 'now' value.
# This is useful for processing items that are due, like in a task scheduler.
#
# @param now: The current time or score to check against.
# @return: An array of members that were popped.
func pop_ready(key: String, now: int) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	if not _gedis._core._sorted_sets.has(key):
		return []

	var data: Dictionary = _gedis._core._sorted_sets[key]
	var ready_members: Array = []
	var i: int = 0
	while i < data.sorted_set.size():
		var entry = data.sorted_set[i]
		if entry[0] <= now:
			ready_members.append(entry[1])
			data.member_scores.erase(entry[1])
			data.sorted_set.remove_at(i)
		else:
			break
	
	if data.sorted_set.is_empty():
		_gedis._core._sorted_sets.erase(key)
	else:
		_gedis._core._sorted_sets[key] = data
	return ready_members


func zscore(key: String, member: String) -> Variant:
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._sorted_sets.has(key):
		return null

	var data: Dictionary = _gedis._core._sorted_sets[key]
	if not data.member_scores.has(member):
		return null

	return data.member_scores[member]


func zrank(key: String, member: String) -> Variant:
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._sorted_sets.has(key):
		return null

	var data: Dictionary = _gedis._core._sorted_sets[key]
	if not data.member_scores.has(member):
		return null

	for i in range(data.sorted_set.size()):
		if data.sorted_set[i][1] == member:
			return i
	return null


func zrevrank(key: String, member: String) -> Variant:
	if _gedis._expiry._is_expired(key):
		return null
	if not _gedis._core._sorted_sets.has(key):
		return null

	var data: Dictionary = _gedis._core._sorted_sets[key]
	if not data.member_scores.has(member):
		return null

	for i in range(data.sorted_set.size() - 1, -1, -1):
		if data.sorted_set[i][1] == member:
			return data.sorted_set.size() - 1 - i
	return null


func zcount(key: String, min_score, max_score) -> int:
	if _gedis._expiry._is_expired(key):
		return 0
	if not _gedis._core._sorted_sets.has(key):
		return 0

	var data: Dictionary = _gedis._core._sorted_sets[key]
	var count: int = 0
	for entry in data.sorted_set:
		var score = entry[0]
		if score >= min_score and score <= max_score:
			count += 1
	return count


func zincrby(key: String, increment, member: String) -> Variant:
	_gedis._core._touch_type(key, _gedis._core._sorted_sets)
	var current_score = zscore(key, member)
	if current_score == null:
		current_score = 0
	var new_score = current_score + increment
	add(key, member, new_score)
	return new_score


func zrangebyscore(key: String, min_score, max_score, withscores: bool = false) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	if not _gedis._core._sorted_sets.has(key):
		return []

	var data: Dictionary = _gedis._core._sorted_sets[key]
	var result: Array = []
	for entry in data.sorted_set:
		var score = entry[0]
		var member = entry[1]
		if score >= min_score and score <= max_score:
			if withscores:
				result.append([member, score])
			else:
				result.append(member)
	return result


func zrevrangebyscore(key: String, min_score, max_score, withscores: bool = false) -> Array:
	var result = zrangebyscore(key, min_score, max_score, withscores)
	result.reverse()
	return result


func zunionstore(destination: String, keys: Array, aggregate: String = "SUM") -> int:
	var temp_scores: Dictionary = {}
	for key in keys:
		if not _gedis._core._sorted_sets.has(key):
			continue
		var data: Dictionary = _gedis._core._sorted_sets[key]
		for member in data.member_scores:
			var score = data.member_scores[member]
			if not temp_scores.has(member):
				temp_scores[member] = score
			else:
				match aggregate.to_upper():
					"SUM":
						temp_scores[member] += score
					"MIN":
						temp_scores[member] = min(temp_scores[member], score)
					"MAX":
						temp_scores[member] = max(temp_scores[member], score)

	if _gedis._core._sorted_sets.has(destination):
		_gedis.del([destination])

	for member in temp_scores:
		add(destination, member, temp_scores[member])

	if not _gedis._core._sorted_sets.has(destination):
		return 0
	return _gedis._core._sorted_sets[destination].sorted_set.size()


func zinterstore(destination: String, keys: Array, aggregate: String = "SUM") -> int:
	if keys.is_empty():
		return 0

	var member_sets: Array = []
	for key in keys:
		if not _gedis._core._sorted_sets.has(key):
			return 0
		var data: Dictionary = _gedis._core._sorted_sets[key]
		member_sets.append(data.member_scores.keys())

	var intersection = member_sets[0]
	for i in range(1, member_sets.size()):
		var next_set = member_sets[i]
		var current_intersection: Array = []
		for member in intersection:
			if member in next_set:
				current_intersection.append(member)
		intersection = current_intersection

	var temp_scores: Dictionary = {}
	for member in intersection:
		var score_sum = 0
		var score_min = INF
		var score_max = - INF
		for key in keys:
			var data: Dictionary = _gedis._core._sorted_sets[key]
			var score = data.member_scores[member]
			score_sum += score
			score_min = min(score_min, score)
			score_max = max(score_max, score)

		match aggregate.to_upper():
			"SUM":
				temp_scores[member] = score_sum
			"MIN":
				temp_scores[member] = score_min
			"MAX":
				temp_scores[member] = score_max

	if _gedis._core._sorted_sets.has(destination):
		_gedis.del([destination])

	for member in temp_scores:
		add(destination, member, temp_scores[member])

	if not _gedis._core._sorted_sets.has(destination):
		return 0
	return _gedis._core._sorted_sets[destination].sorted_set.size()
