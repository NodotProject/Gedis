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

func test_zrem():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	assert_eq(gedis.zrem("key", "a"), 1)
	assert_eq(gedis.zrem("key", "c"), 0)
	assert_eq(gedis.zrange("key", 0, -1), ["b"])

func test_zrevrange():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zrevrange("key", 0, -1), ["c", "b", "a"])
	assert_eq(gedis.zrevrange("key", 1, 2), ["b", "a"])
	assert_eq(gedis.zrevrange("key", 0, -1, true), [["c", 3], ["b", 2], ["a", 1]])

func test_zpopready():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zpopready("key", 2), ["a", "b"])
	assert_eq(gedis.zrange("key", 0, -1), ["c"])

func test_zscore():
	gedis.zadd("key", "a", 1)
	assert_eq(gedis.zscore("key", "a"), 1)
	assert_null(gedis.zscore("key", "b"))

func test_zrank():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zrank("key", "a"), 0)
	assert_eq(gedis.zrank("key", "b"), 1)
	assert_eq(gedis.zrank("key", "c"), 2)
	assert_null(gedis.zrank("key", "d"))

func test_zrevrank():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zrevrank("key", "a"), 2)
	assert_eq(gedis.zrevrank("key", "b"), 1)
	assert_eq(gedis.zrevrank("key", "c"), 0)
	assert_null(gedis.zrevrank("key", "d"))

func test_zcount():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zcount("key", 1, 2), 2)
	assert_eq(gedis.zcount("key", 2, 3), 2)
	assert_eq(gedis.zcount("key", 4, 5), 0)

func test_zincrby():
	gedis.zadd("key", "a", 1)
	assert_eq(gedis.zincrby("key", 2, "a"), 3)
	assert_eq(gedis.zscore("key", "a"), 3)
	assert_eq(gedis.zincrby("key", 2, "b"), 2)
	assert_eq(gedis.zscore("key", "b"), 2)

func test_zrangebyscore():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zrangebyscore("key", 1, 2), ["a", "b"])
	assert_eq(gedis.zrangebyscore("key", 2, 3), ["b", "c"])
	assert_eq(gedis.zrangebyscore("key", 1, 2, true), [["a", 1], ["b", 2]])

func test_zrevrangebyscore():
	gedis.zadd("key", "a", 1)
	gedis.zadd("key", "b", 2)
	gedis.zadd("key", "c", 3)
	assert_eq(gedis.zrevrangebyscore("key", 1, 2), ["b", "a"])
	assert_eq(gedis.zrevrangebyscore("key", 2, 3), ["c", "b"])
	assert_eq(gedis.zrevrangebyscore("key", 1, 2, true), [["b", 2], ["a", 1]])
