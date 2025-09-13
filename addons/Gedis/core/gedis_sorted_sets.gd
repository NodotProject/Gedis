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
# @return: An array of members within the score range.
func range_by_score(key: String, min_score: int, max_score: int) -> Array:
	if _gedis._expiry._is_expired(key):
		return []
	if not _gedis._core._sorted_sets.has(key):
		return []
		
	var data: Dictionary = _gedis._core._sorted_sets[key]
	var result: Array = []
	for entry in data.sorted_set:
		if entry[0] >= min_score and entry[0] <= max_score:
			result.append(entry[1])
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