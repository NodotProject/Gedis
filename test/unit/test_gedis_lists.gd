extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushdb()

func after_all():
	gedis.free()

func before_each():
	gedis.flushdb()

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
