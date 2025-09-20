extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushall()

func after_all():
	gedis.free()

func before_each():
	gedis.flushall()

func test_type():
	gedis.set_value("string_key", "hello")
	assert_eq(gedis.type("string_key"), "string", "type should be string")

	gedis.hset("hash_key", "field", "value")
	assert_eq(gedis.type("hash_key"), "hash", "type should be hash")

	gedis.lpush("list_key", "value")
	assert_eq(gedis.type("list_key"), "list", "type should be list")

	gedis.sadd("set_key", "member")
	assert_eq(gedis.type("set_key"), "set", "type should be set")

	gedis.zadd("zset_key", "member", 1)
	assert_eq(gedis.type("zset_key"), "zset", "type should be zset")

	assert_eq(gedis.type("nonexistent_key"), "none", "type should be none for nonexistent key")

func test_dump():
	gedis.set_value("mykey", "myvalue")
	var dump = gedis.dump_key("mykey")
	assert_true(dump.has("type"), "dump should have a type")
	assert_eq(dump["type"], "string", "dump type should be string")
	assert_true(dump.has("value"), "dump should have a value")
	assert_eq(dump["value"], "myvalue", "dump value should be correct")
	assert_true(dump.has("ttl"), "dump should have a ttl")
	assert_eq(dump["ttl"], -1, "dump ttl should be -1 for no expiry")

	gedis.expire("mykey", 120)
	dump = gedis.dump_key("mykey")
	assert_true(dump["ttl"] > 0 and dump["ttl"] <= 120, "dump ttl should be between 0 and 120")

func test_snapshot():
	gedis.set_value("user:1", "Alice")
	gedis.hset("user:2", "name", "Bob")
	gedis.lpush("messages", "hello")

	var snapshot = gedis.snapshot()
	assert_eq(snapshot.size(), 3, "snapshot should contain all keys")
	assert_true(snapshot.has("user:1"), "snapshot should have user:1")
	assert_eq(snapshot["user:1"]["value"], "Alice", "snapshot value for user:1 should be correct")

	var user_snapshot = gedis.snapshot("user:*")
	assert_eq(user_snapshot.size(), 2, "snapshot with pattern should contain matching keys")
	assert_true(user_snapshot.has("user:1"), "user snapshot should have user:1")
	assert_true(user_snapshot.has("user:2"), "user snapshot should have user:2")
	assert_false(user_snapshot.has("messages"), "user snapshot should not have messages")