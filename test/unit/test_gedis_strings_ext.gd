extends GutTest

var gedis

func before_each():
	gedis = Gedis.new()

func after_each():
	gedis.free()

func test_set_get():
	var key = "test_key"
	var value = "test_value"
	gedis.set_value(key, value)
	var result = gedis.get_value(key)
	assert_eq(result, value, "get_value should retrieve the value set by set_value")

func test_del():
	var key = "test_key_del"
	var value = "test_value"
	gedis.set_value(key, value)
	assert_eq(gedis.exists([key]), 1, "Key should exist after SET")
	gedis.del([key])
	assert_eq(gedis.exists([key]), 0, "Key should not exist after DEL")

func test_exists():
	var key = "test_key_exists"
	var value = "test_value"
	assert_eq(gedis.exists([key]), 0, "Key should not exist initially")
	gedis.set_value(key, value)
	assert_eq(gedis.exists([key]), 1, "Key should exist after SET")

func test_incr_decr():
	var key = "test_key_incr_decr"
	gedis.set_value(key, 10)
	gedis.incr(key)
	assert_eq(int(gedis.get_value(key)), 11, "INCR should increment the value")
	gedis.decr(key)
	assert_eq(int(gedis.get_value(key)), 10, "DECR should decrement the value")

func test_keys():
	gedis.set_value("key:1", "a")
	gedis.set_value("key:2", "b")
	gedis.set_value("another_key:1", "c")
	var keys = gedis.keys("key:*")
	assert_eq(keys.size(), 2, "KEYS should return the correct number of keys for the pattern")
	assert_true("key:1" in keys, "KEYS should return 'key:1'")
	assert_true("key:2" in keys, "KEYS should return 'key:2'")