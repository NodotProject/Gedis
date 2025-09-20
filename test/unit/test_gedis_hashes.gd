extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushall()

func after_all():
	gedis.free()

func before_each():
	gedis.flushall()

func test_hincrby_field_does_not_exist():
	gedis.hset("key1", "field1", 10)
	var result = gedis.hincrby("key1", "field2", 5)
	assert_eq(result, 5)
	assert_eq(gedis.hget("key1", "field2"), 5)

func test_hincrby_field_exists():
	gedis.hset("key1", "field1", 10)
	var result = gedis.hincrby("key1", "field1", 5)
	assert_eq(result, 15)
	assert_eq(gedis.hget("key1", "field1"), 15)

func test_hincrbyfloat_field_does_not_exist():
	gedis.hset("key1", "field1", 10.5)
	var result = gedis.hincrbyfloat("key1", "field2", 5.5)
	assert_eq(result, 5.5)
	assert_eq(gedis.hget("key1", "field2"), 5.5)

func test_hincrbyfloat_field_exists():
	gedis.hset("key1", "field1", 10.5)
	var result = gedis.hincrbyfloat("key1", "field1", 5.5)
	assert_eq(result, 16.0)
	assert_eq(gedis.hget("key1", "field1"), 16.0)

func test_hmget_all_fields_exist():
	gedis.hset("key1", "field1", "value1")
	gedis.hset("key1", "field2", "value2")
	var result = gedis.hmget("key1", ["field1", "field2"])
	assert_eq(result, ["value1", "value2"])

func test_hmget_some_fields_exist():
	gedis.hset("key1", "field1", "value1")
	var result = gedis.hmget("key1", ["field1", "field2"])
	assert_eq(result, ["value1", null])

func test_hmset():
	gedis.hmset("key1", {"field1": "value1", "field2": "value2"})
	assert_eq(gedis.hget("key1", "field1"), "value1")
	assert_eq(gedis.hget("key1", "field2"), "value2")

func test_hdel_single_field():
	gedis.hset("key1", "field1", "value1")
	var result = gedis.hdel("key1", "field1")
	assert_eq(result, 1)
	assert_null(gedis.hget("key1", "field1"))

func test_hdel_multiple_fields():
	gedis.hset("key1", "field1", "value1")
	gedis.hset("key1", "field2", "value2")
	var result = gedis.hdel("key1", ["field1", "field2"])
	assert_eq(result, 2)
	assert_null(gedis.hget("key1", "field1"))
	assert_null(gedis.hget("key1", "field2"))

func test_hgetall():
	gedis.hset("key1", "field1", "value1")
	gedis.hset("key1", "field2", "value2")
	var result = gedis.hgetall("key1")
	assert_eq(result, {"field1": "value1", "field2": "value2"})

func test_hexists_field_exists():
	gedis.hset("key1", "field1", "value1")
	assert_true(gedis.hexists("key1", "field1"))

func test_hexists_field_does_not_exist():
	assert_false(gedis.hexists("key1", "field1"))

func test_hkeys():
	gedis.hset("key1", "field1", "value1")
	gedis.hset("key1", "field2", "value2")
	var result = gedis.hkeys("key1")
	assert_eq(result, ["field1", "field2"])

func test_hvals():
	gedis.hset("key1", "field1", "value1")
	gedis.hset("key1", "field2", "value2")
	var result = gedis.hvals("key1")
	assert_eq(result, ["value1", "value2"])

func test_hlen():
	gedis.hset("key1", "field1", "value1")
	gedis.hset("key1", "field2", "value2")
	var result = gedis.hlen("key1")
	assert_eq(result, 2)


func test_hexists_key_exists():
	gedis.hset("key1", "field1", "value1")
	assert_true(gedis.hexists("key1"))

func test_hexists_key_does_not_exist():
	assert_false(gedis.hexists("key1"))

func test_del_hash():
	gedis.hset("myhash", "field1", "value1")
	assert_true(gedis.key_exists("myhash"), "hash should exist before del")
	var result = gedis.del("myhash")
	assert_eq(result, 1, "del should return 1 for an existing hash")
	assert_false(gedis.key_exists("myhash"), "hash should not exist after del")
	assert_eq(gedis.hgetall("myhash"), {}, "hgetall on deleted hash should be empty")
