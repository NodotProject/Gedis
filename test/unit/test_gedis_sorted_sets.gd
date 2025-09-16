extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushdb()

func after_all():
	gedis.free()

func before_each():
	gedis.flushdb()

func test_zunionstore():
	gedis.zadd("key1", "a", 1)
	gedis.zadd("key1", "b", 2)
	gedis.zadd("key2", "b", 3)
	gedis.zadd("key2", "c", 4)
	var result = gedis.zunionstore("key3", ["key1", "key2"])
	assert_eq(result, 3)
	assert_eq(gedis.zrange("key3", 0, -1, true), ["a", 1, "c", 4, "b", 5])

func test_zinterstore():
	gedis.zadd("key1", "a", 1)
	gedis.zadd("key1", "b", 2)
	gedis.zadd("key2", "b", 3)
	gedis.zadd("key2", "c", 4)
	var result = gedis.zinterstore("key3", ["key1", "key2"])
	assert_eq(result, 1)
	assert_eq(gedis.zrange("key3", 0, -1, true), ["b", 5])
