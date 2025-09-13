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

class_name GedisSortedSets

# The internal array storing the sorted set as [score, member] pairs.
# This array is kept sorted by score to allow for efficient range queries.
var _sorted_set: Array = []

# A dictionary mapping members to their scores for quick lookups.
# This allows for O(1) access to a member's score.
var _member_scores: Dictionary = {}


# Adds a new member to the sorted set with the specified score.
# If the member already exists, its score is updated, and its position in the set is adjusted.
#
# @param member: The member to add or update.
# @param score: The score associated with the member.
func add(member: String, score: int) -> int:
	var new_member = not _member_scores.has(member)
	if not new_member:
		remove(member)

	_member_scores[member] = score
	var entry = [score, member]
	var inserted: bool = false
	for i in range(_sorted_set.size()):
		if score < _sorted_set[i][0]:
			_sorted_set.insert(i, entry)
			inserted = true
			break
	if not inserted:
		_sorted_set.append(entry)
	
	return 1 if new_member else 0


# Removes a member from the sorted set.
#
# @param member: The member to remove.
func remove(member: String) -> int:
	if not _member_scores.has(member):
		return 0

	var score = _member_scores[member]
	_member_scores.erase(member)

	for i in range(_sorted_set.size()):
		if _sorted_set[i][0] == score and _sorted_set[i][1] == member:
			_sorted_set.remove_at(i)
			return 1
	return 0


# Returns an array of members within the specified score range (inclusive).
#
# @param min_score: The minimum score of the range.
# @param max_score: The maximum score of the range.
# @return: An array of members within the score range.
func range_by_score(min_score: int, max_score: int) -> Array:
	var result: Array = []
	for entry in _sorted_set:
		if entry[0] >= min_score and entry[0] <= max_score:
			result.append(entry[1])
	return result


# Removes and returns members with scores up to the given 'now' value.
# This is useful for processing items that are due, like in a task scheduler.
#
# @param now: The current time or score to check against.
# @return: An array of members that were popped.
func pop_ready(now: int) -> Array:
	var ready_members: Array = []
	var i: int = 0
	while i < _sorted_set.size():
		var entry = _sorted_set[i]
		if entry[0] <= now:
			ready_members.append(entry[1])
			_member_scores.erase(entry[1])
			_sorted_set.remove_at(i)
		else:
			break
	return ready_members