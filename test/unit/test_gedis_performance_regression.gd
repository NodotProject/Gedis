extends GutTest

# Regression tests for areas targeted by performance optimizations.
# These tests ensure correctness is preserved after optimization changes.

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushall()

func after_all():
	gedis.free()

func before_each():
	gedis.flushall()


# ===========================================
# 1. Sorted Set add() — binary search insertion
# ===========================================

func test_zadd_maintains_sort_order():
	gedis.zadd("z", "c", 30)
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 20)
	assert_eq(gedis.zrange("z", 0, -1), ["a", "b", "c"])

func test_zadd_duplicate_scores_maintains_insertion():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 10)
	gedis.zadd("z", "c", 10)
	var result = gedis.zrange("z", 0, -1)
	assert_eq(result.size(), 3)
	assert_true(result.has("a"))
	assert_true(result.has("b"))
	assert_true(result.has("c"))

func test_zadd_update_score_reorders():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 20)
	gedis.zadd("z", "c", 30)
	# Move "a" to highest score
	gedis.zadd("z", "a", 50)
	assert_eq(gedis.zrange("z", 0, -1), ["b", "c", "a"])
	assert_eq(gedis.zscore("z", "a"), 50)

func test_zadd_update_returns_zero():
	gedis.zadd("z", "a", 10)
	var result = gedis.zadd("z", "a", 20)
	assert_eq(result, 0, "updating existing member should return 0")

func test_zadd_new_returns_one():
	var result = gedis.zadd("z", "a", 10)
	assert_eq(result, 1, "adding new member should return 1")

func test_zadd_negative_scores():
	gedis.zadd("z", "a", -10)
	gedis.zadd("z", "b", -5)
	gedis.zadd("z", "c", 0)
	gedis.zadd("z", "d", 5)
	assert_eq(gedis.zrange("z", 0, -1), ["a", "b", "c", "d"])

func test_zadd_large_set_ordering():
	for i in range(200):
		gedis.zadd("z", "m_%d" % i, 200 - i)
	# First member should be the one with score 1
	assert_eq(gedis.zrange("z", 0, 0), ["m_199"])
	# Last member should be the one with score 200
	assert_eq(gedis.zrange("z", -1, -1), ["m_0"])
	assert_eq(gedis.zcard("z"), 200)

func test_zadd_update_all_members_preserves_count():
	for i in range(50):
		gedis.zadd("z", "m_%d" % i, i)
	for i in range(50):
		gedis.zadd("z", "m_%d" % i, 50 - i)
	assert_eq(gedis.zcard("z"), 50)


# ===========================================
# 2. Pub/Sub publish — pattern regex caching
# ===========================================

func test_publish_pattern_matching_still_works():
	var received = []
	var sub = _PatternSubscriber.new(received)
	get_tree().root.add_child(sub)
	gedis.psubscribe("test:*", sub)

	# Direct call (not deferred) to test synchronously
	gedis._pubsub.publish("test:hello", "msg1")

	assert_eq(received.size(), 1)
	assert_eq(received[0]["channel"], "test:hello")
	assert_eq(received[0]["message"], "msg1")

	sub.queue_free()

func test_publish_pattern_no_false_match():
	var received = []
	var sub = _PatternSubscriber.new(received)
	get_tree().root.add_child(sub)
	gedis.psubscribe("foo:*", sub)

	gedis._pubsub.publish("bar:hello", "msg1")
	assert_eq(received.size(), 0, "pattern foo:* should not match bar:hello")

	sub.queue_free()

func test_publish_multiple_patterns():
	var received = []
	var sub = _PatternSubscriber.new(received)
	get_tree().root.add_child(sub)
	gedis.psubscribe("a:*", sub)
	gedis.psubscribe("b:*", sub)

	gedis._pubsub.publish("a:1", "x")
	gedis._pubsub.publish("b:2", "y")
	gedis._pubsub.publish("c:3", "z")

	assert_eq(received.size(), 2)

	sub.queue_free()


# ===========================================
# 3. _touch_type — early return optimization
# ===========================================

func test_overwrite_same_type_preserves_value():
	gedis.set_value("k", "v1")
	gedis.set_value("k", "v2")
	assert_eq(gedis.get_value("k"), "v2")

func test_type_change_clears_old_type():
	gedis.set_value("k", "string_val")
	assert_true(gedis.key_exists("k"))

	# Now use same key as a hash
	gedis.hset("k", "field", "val")
	# Old string value should be gone
	assert_eq(gedis.get_value("k"), null)
	assert_eq(gedis.hget("k", "field"), "val")

func test_type_change_string_to_list():
	gedis.set_value("k", "hello")
	gedis.lpush("k", "item")
	assert_eq(gedis.get_value("k"), null)
	assert_eq(gedis.lget("k"), ["item"])

func test_type_change_list_to_set():
	gedis.lpush("k", "item")
	gedis.sadd("k", "member")
	assert_false(gedis.lexists("k"))
	assert_true(gedis.sismember("k", "member"))

func test_type_change_set_to_sorted_set():
	gedis.sadd("k", "member")
	gedis.zadd("k", "member", 10)
	assert_false(gedis.sexists("k"))
	assert_true(gedis.zexists("k"))

func test_type_change_hash_to_string():
	gedis.hset("k", "f", "v")
	gedis.set_value("k", "str")
	assert_eq(gedis.get_value("k"), "str")
	assert_false(gedis.hexists("k"))


# ===========================================
# 4. _delete_all_types_for_key — targeted delete
# ===========================================

func test_del_removes_string():
	gedis.set_value("k", "v")
	gedis.del("k")
	assert_false(gedis.key_exists("k"))

func test_del_removes_hash():
	gedis.hset("k", "f", "v")
	gedis.del("k")
	assert_false(gedis.hexists("k"))

func test_del_removes_list():
	gedis.lpush("k", "v")
	gedis.del("k")
	assert_false(gedis.lexists("k"))

func test_del_removes_set():
	gedis.sadd("k", "v")
	gedis.del("k")
	assert_false(gedis.sexists("k"))

func test_del_removes_sorted_set():
	gedis.zadd("k", "v", 1)
	gedis.del("k")
	assert_false(gedis.zexists("k"))

func test_del_removes_expiry():
	gedis.set_value("k", "v")
	gedis.expire("k", 100)
	assert_true(gedis.ttl("k") > 0)
	gedis.del("k")
	assert_eq(gedis.ttl("k"), -2)


# ===========================================
# 5. key_exists / _get_all_keys — unified index
# ===========================================

func test_key_exists_all_types():
	gedis.set_value("str_key", "v")
	gedis.hset("hash_key", "f", "v")
	gedis.lpush("list_key", "v")
	gedis.sadd("set_key", "m")
	gedis.zadd("zset_key", "m", 1)

	assert_true(gedis.key_exists("str_key"))
	assert_true(gedis.key_exists("hash_key"))
	assert_true(gedis.key_exists("list_key"))
	assert_true(gedis.key_exists("set_key"))
	assert_true(gedis.key_exists("zset_key"))
	assert_false(gedis.key_exists("missing"))

func test_dbsize_counts_all_types():
	gedis.set_value("s1", "v")
	gedis.hset("h1", "f", "v")
	gedis.lpush("l1", "v")
	gedis.sadd("st1", "m")
	gedis.zadd("z1", "m", 1)
	assert_eq(gedis.dbsize(), 5)

func test_keys_pattern_all_types():
	gedis.set_value("user:1", "v")
	gedis.hset("user:2", "f", "v")
	gedis.lpush("user:3", "v")
	gedis.sadd("other:1", "m")

	var user_keys = gedis.keys("user:*")
	assert_eq(user_keys.size(), 3)
	assert_true(user_keys.has("user:1"))
	assert_true(user_keys.has("user:2"))
	assert_true(user_keys.has("user:3"))

func test_dbsize_after_deletions():
	for i in range(10):
		gedis.set_value("key_%d" % i, i)
	assert_eq(gedis.dbsize(), 10)
	gedis.del(["key_0", "key_1", "key_2"])
	assert_eq(gedis.dbsize(), 7)

func test_dbsize_after_type_change():
	gedis.set_value("k", "v")
	assert_eq(gedis.dbsize(), 1)
	# Change type — should still be 1 key, not 2
	gedis.hset("k", "f", "v")
	assert_eq(gedis.dbsize(), 1)


# ===========================================
# 6. sinter — dictionary-based lookup
# ===========================================

func test_sinter_basic():
	gedis.sadd("s1", "a")
	gedis.sadd("s1", "b")
	gedis.sadd("s1", "c")
	gedis.sadd("s2", "b")
	gedis.sadd("s2", "c")
	gedis.sadd("s2", "d")
	var result = gedis.sinter(["s1", "s2"])
	result.sort()
	assert_eq(result, ["b", "c"])

func test_sinter_no_overlap():
	gedis.sadd("s1", "a")
	gedis.sadd("s2", "b")
	assert_eq(gedis.sinter(["s1", "s2"]), [])

func test_sinter_three_sets():
	gedis.sadd("s1", "a")
	gedis.sadd("s1", "b")
	gedis.sadd("s1", "c")
	gedis.sadd("s2", "b")
	gedis.sadd("s2", "c")
	gedis.sadd("s3", "c")
	gedis.sadd("s3", "d")
	var result = gedis.sinter(["s1", "s2", "s3"])
	assert_eq(result, ["c"])

func test_sinter_empty_set():
	gedis.sadd("s1", "a")
	assert_eq(gedis.sinter(["s1", "s2"]).size(), 0)

func test_sinter_single_set():
	gedis.sadd("s1", "a")
	gedis.sadd("s1", "b")
	var result = gedis.sinter(["s1"])
	result.sort()
	assert_eq(result, ["a", "b"])

func test_sinterstore_correctness():
	gedis.sadd("s1", "a")
	gedis.sadd("s1", "b")
	gedis.sadd("s2", "b")
	gedis.sadd("s2", "c")
	var count = gedis.sinterstore("dest", ["s1", "s2"])
	assert_eq(count, 1)
	assert_true(gedis.sismember("dest", "b"))
	assert_false(gedis.sismember("dest", "a"))


# ===========================================
# 7. List ops — in-place modification
# ===========================================

func test_lpop_preserves_remaining():
	gedis.rpush("l", [1, 2, 3, 4, 5])
	assert_eq(gedis.lpop("l"), 1)
	assert_eq(gedis.lget("l"), [2, 3, 4, 5])

func test_rpop_preserves_remaining():
	gedis.rpush("l", [1, 2, 3, 4, 5])
	assert_eq(gedis.rpop("l"), 5)
	assert_eq(gedis.lget("l"), [1, 2, 3, 4])

func test_lpop_until_empty_cleans_up():
	gedis.rpush("l", [1, 2])
	gedis.lpop("l")
	gedis.lpop("l")
	assert_null(gedis.lpop("l"))
	assert_false(gedis.lexists("l"))

func test_rpop_until_empty_cleans_up():
	gedis.rpush("l", [1, 2])
	gedis.rpop("l")
	gedis.rpop("l")
	assert_null(gedis.rpop("l"))
	assert_false(gedis.lexists("l"))

func test_lset_does_not_corrupt_list():
	gedis.rpush("l", [1, 2, 3, 4, 5])
	gedis.lset("l", 2, 99)
	assert_eq(gedis.lget("l"), [1, 2, 99, 4, 5])
	assert_eq(gedis.llen("l"), 5)

func test_lrem_does_not_corrupt_list():
	gedis.rpush("l", ["a", "b", "a", "c", "a"])
	gedis.lrem("l", 1, "a")
	assert_eq(gedis.lget("l"), ["b", "a", "c", "a"])

func test_ltrim_does_not_corrupt_list():
	gedis.rpush("l", [1, 2, 3, 4, 5])
	gedis.ltrim("l", 1, 3)
	assert_eq(gedis.lget("l"), [2, 3, 4])

func test_linsert_does_not_corrupt_list():
	gedis.rpush("l", [1, 2, 3])
	gedis.linsert("l", "BEFORE", 2, 99)
	assert_eq(gedis.lget("l"), [1, 99, 2, 3])

func test_multiple_lpops_sequential():
	gedis.rpush("l", [10, 20, 30, 40, 50])
	assert_eq(gedis.lpop("l"), 10)
	assert_eq(gedis.lpop("l"), 20)
	assert_eq(gedis.lpop("l"), 30)
	assert_eq(gedis.lget("l"), [40, 50])


# ===========================================
# 8. zrevrange — backwards iteration
# ===========================================

func test_zrevrange_full():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	gedis.zadd("z", "c", 3)
	assert_eq(gedis.zrevrange("z", 0, -1), ["c", "b", "a"])

func test_zrevrange_partial():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	gedis.zadd("z", "c", 3)
	gedis.zadd("z", "d", 4)
	gedis.zadd("z", "e", 5)
	assert_eq(gedis.zrevrange("z", 0, 2), ["e", "d", "c"])
	assert_eq(gedis.zrevrange("z", 1, 3), ["d", "c", "b"])

func test_zrevrange_with_scores():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	gedis.zadd("z", "c", 3)
	assert_eq(gedis.zrevrange("z", 0, -1, true), [["c", 3], ["b", 2], ["a", 1]])

func test_zrevrange_single_element():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	gedis.zadd("z", "c", 3)
	assert_eq(gedis.zrevrange("z", 0, 0), ["c"])

func test_zrevrange_empty():
	assert_eq(gedis.zrevrange("z", 0, -1), [])

func test_zrevrange_out_of_bounds():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	# Requesting beyond the set size should clamp
	assert_eq(gedis.zrevrange("z", 0, 10), ["b", "a"])


# ===========================================
# 9. zrank / zrevrank — score-based binary search
# ===========================================

func test_zrank_basic():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 20)
	gedis.zadd("z", "c", 30)
	assert_eq(gedis.zrank("z", "a"), 0)
	assert_eq(gedis.zrank("z", "b"), 1)
	assert_eq(gedis.zrank("z", "c"), 2)

func test_zrevrank_basic():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 20)
	gedis.zadd("z", "c", 30)
	assert_eq(gedis.zrevrank("z", "a"), 2)
	assert_eq(gedis.zrevrank("z", "b"), 1)
	assert_eq(gedis.zrevrank("z", "c"), 0)

func test_zrank_after_score_update():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 20)
	gedis.zadd("z", "c", 30)
	gedis.zadd("z", "a", 50)
	assert_eq(gedis.zrank("z", "a"), 2)
	assert_eq(gedis.zrank("z", "b"), 0)

func test_zrank_missing_member():
	gedis.zadd("z", "a", 10)
	assert_null(gedis.zrank("z", "missing"))

func test_zrank_missing_key():
	assert_null(gedis.zrank("missing", "a"))

func test_zrank_duplicate_scores():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 10)
	gedis.zadd("z", "c", 10)
	# All have same score — ranks should still be unique and valid
	var ranks = [gedis.zrank("z", "a"), gedis.zrank("z", "b"), gedis.zrank("z", "c")]
	ranks.sort()
	assert_eq(ranks, [0, 1, 2])


# ===========================================
# 10. zcount / zrangebyscore — binary search on sorted data
# ===========================================

func test_zcount_basic():
	for i in range(10):
		gedis.zadd("z", "m_%d" % i, i * 10)
	assert_eq(gedis.zcount("z", 0, 90), 10)
	assert_eq(gedis.zcount("z", 20, 50), 4)
	assert_eq(gedis.zcount("z", 100, 200), 0)

func test_zcount_single_score():
	gedis.zadd("z", "a", 10)
	gedis.zadd("z", "b", 10)
	gedis.zadd("z", "c", 10)
	assert_eq(gedis.zcount("z", 10, 10), 3)

func test_zrangebyscore_basic():
	for i in range(10):
		gedis.zadd("z", "m_%d" % i, i * 10)
	var result = gedis.zrangebyscore("z", 20, 50)
	assert_eq(result.size(), 4)
	assert_eq(result[0], "m_2")
	assert_eq(result[3], "m_5")

func test_zrangebyscore_with_scores():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	gedis.zadd("z", "c", 3)
	var result = gedis.zrangebyscore("z", 1, 2, true)
	assert_eq(result, [["a", 1], ["b", 2]])

func test_zrangebyscore_no_match():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	assert_eq(gedis.zrangebyscore("z", 10, 20), [])

func test_zrevrangebyscore_basic():
	gedis.zadd("z", "a", 1)
	gedis.zadd("z", "b", 2)
	gedis.zadd("z", "c", 3)
	assert_eq(gedis.zrevrangebyscore("z", 1, 3), ["c", "b", "a"])

func test_zcount_empty_key():
	assert_eq(gedis.zcount("missing", 0, 100), 0)

func test_zrangebyscore_empty_key():
	assert_eq(gedis.zrangebyscore("missing", 0, 100), [])


# ===========================================
# Helper classes
# ===========================================

class _PatternSubscriber extends Node:
	signal psub_message(pattern, channel, message)

	var _received: Array

	func _init(received: Array):
		_received = received
		psub_message.connect(_on_psub)

	func _on_psub(pattern: String, channel: String, message: Variant):
		_received.append({"pattern": pattern, "channel": channel, "message": message})
