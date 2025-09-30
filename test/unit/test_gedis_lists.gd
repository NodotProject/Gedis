extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushall()

func after_all():
	gedis.free()

func before_each():
	gedis.flushall()

func test_linsert_before_pivot():
	gedis.rpush("key1", ["a", "b", "c"])
	var result = gedis.linsert("key1", "BEFORE", "b", "x")
	assert_eq(result, 4)
	assert_eq(gedis.lrange("key1", 0, -1), ["a", "x", "b", "c"])

func test_linsert_after_pivot():
	gedis.rpush("key1", ["a", "b", "c"])
	var result = gedis.linsert("key1", "AFTER", "b", "x")
	assert_eq(result, 4)
	assert_eq(gedis.lrange("key1", 0, -1), ["a", "b", "x", "c"])

func test_linsert_pivot_not_found():
	gedis.rpush("key1", ["a", "b", "c"])
	var result = gedis.linsert("key1", "BEFORE", "y", "x")
	assert_eq(result, -1)
	assert_eq(gedis.lrange("key1", 0, -1), ["a", "b", "c"])

func test_linsert_key_not_found():
	var result = gedis.linsert("key1", "BEFORE", "y", "x")
	assert_eq(result, 0)

func test_rpop():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_eq(gedis.rpop("key1"), "c")
	assert_eq(gedis.lrange("key1", 0, -1), ["a", "b"])

func test_rpop_empty_list():
	gedis.rpush("key1", [])
	assert_null(gedis.rpop("key1"))

func test_rpop_non_existent_key():
	assert_null(gedis.rpop("non_existent_key"))

func test_llen():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_eq(gedis.llen("key1"), 3)

func test_llen_empty_list():
	gedis.rpush("key1", [])
	assert_eq(gedis.llen("key1"), 0)

func test_llen_non_existent_key():
	assert_eq(gedis.llen("non_existent_key"), 0)

func test_lget():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_eq(gedis.lget("key1"), ["a", "b", "c"])

func test_lget_empty_list():
	gedis.rpush("key1", [])
	assert_eq(gedis.lget("key1"), [])

func test_lget_non_existent_key():
	assert_eq(gedis.lget("non_existent_key"), [])

func test_lindex():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_eq(gedis.lindex("key1", 0), "a")
	assert_eq(gedis.lindex("key1", 1), "b")
	assert_eq(gedis.lindex("key1", -1), "c")

func test_lindex_out_of_bounds():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_null(gedis.lindex("key1", 5))
	assert_null(gedis.lindex("key1", -5))

func test_lset():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_true(gedis.lset("key1", 1, "x"))
	assert_eq(gedis.lget("key1"), ["a", "x", "c"])

func test_lset_negative_index():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_true(gedis.lset("key1", -1, "z"))
	assert_eq(gedis.lget("key1"), ["a", "b", "z"])

func test_lset_out_of_bounds():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_false(gedis.lset("key1", 5, "x"))
	assert_false(gedis.lset("key1", -5, "x"))

func test_lrem_from_head():
	gedis.rpush("key1", ["a", "b", "a", "c", "a"])
	assert_eq(gedis.lrem("key1", 2, "a"), 2)
	assert_eq(gedis.lget("key1"), ["b", "c", "a"])

func test_lrem_from_tail():
	gedis.rpush("key1", ["a", "b", "a", "c", "a"])
	assert_eq(gedis.lrem("key1", -2, "a"), 2)
	assert_eq(gedis.lget("key1"), ["a", "b", "c"])

func test_lrem_all():
	gedis.rpush("key1", ["a", "b", "a", "c", "a"])
	assert_eq(gedis.lrem("key1", 0, "a"), 3)
	assert_eq(gedis.lget("key1"), ["b", "c"])

func test_ltrim():
	gedis.rpush("key1", ["a", "b", "c", "d", "e"])
	assert_true(gedis.ltrim("key1", 1, 3))
	assert_eq(gedis.lget("key1"), ["b", "c", "d"])

func test_ltrim_negative_indices():
	gedis.rpush("key1", ["a", "b", "c", "d", "e"])
	assert_true(gedis.ltrim("key1", -3, -2))
	assert_eq(gedis.lget("key1"), ["c", "d"])

func test_ltrim_out_of_bounds():
	gedis.rpush("key1", ["a", "b", "c"])
	assert_true(gedis.ltrim("key1", 1, 5))
	assert_eq(gedis.lget("key1"), ["b", "c"])

func test_lmove():
	gedis.rpush("source", ["one", "two", "three"])
	gedis.rpush("destination", ["four", "five", "six"])

	# LEFT to LEFT
	assert_eq(gedis.lmove("source", "destination", "LEFT", "LEFT"), "one")
	assert_eq(gedis.lget("source"), ["two", "three"])
	assert_eq(gedis.lget("destination"), ["one", "four", "five", "six"])

	# LEFT to RIGHT
	assert_eq(gedis.lmove("source", "destination", "LEFT", "RIGHT"), "two")
	assert_eq(gedis.lget("source"), ["three"])
	assert_eq(gedis.lget("destination"), ["one", "four", "five", "six", "two"])

	# RIGHT to LEFT
	gedis.rpush("source2", ["seven", "eight", "nine"])
	assert_eq(gedis.lmove("source2", "destination", "RIGHT", "LEFT"), "nine")
	assert_eq(gedis.lget("source2"), ["seven", "eight"])
	assert_eq(gedis.lget("destination"), ["nine", "one", "four", "five", "six", "two"])

	# RIGHT to RIGHT
	assert_eq(gedis.lmove("source2", "destination", "RIGHT", "RIGHT"), "eight")
	assert_eq(gedis.lget("source2"), ["seven"])
	assert_eq(gedis.lget("destination"), ["nine", "one", "four", "five", "six", "two", "eight"])

func test_lmove_source_not_found():
	gedis.rpush("destination", ["one", "two", "three"])
	assert_null(gedis.lmove("nonexistent", "destination", "LEFT", "LEFT"))
	assert_eq(gedis.lget("destination"), ["one", "two", "three"])

func test_lmove_destination_not_found():
	gedis.rpush("source", ["one", "two", "three"])
	assert_eq(gedis.lmove("source", "nonexistent", "LEFT", "LEFT"), "one")
	assert_eq(gedis.lget("source"), ["two", "three"])
	assert_eq(gedis.lget("nonexistent"), ["one"])

func test_lexists():
	assert_false(gedis.lexists("nonexistent_list"))
	gedis.lpush("test_list", "item1")
	assert_true(gedis.lexists("test_list"))
	gedis.lpop("test_list")
	assert_false(gedis.lexists("test_list"))
