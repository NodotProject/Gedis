extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushdb()

func after_all():
	gedis.free()

func before_each():
	gedis.flushdb()

func test_set_get():
	gedis.set_value("a", "1")
	assert_eq(gedis.get_value("a"), "1", "get_value should return what was set")
	assert_eq(gedis.get_value("missing"), null, "get_value should return null when missing")

func test_incr_decrby():
	assert_eq(gedis.incrby("n"), 1, "incr on non-existent key should return 1")
	assert_eq(gedis.incrby("n"), 2, "incr should increment existing value")
	assert_eq(gedis.decrby("n"), 1, "decr should decrement existing value")

func test_del_exists_and_keys():
	gedis.set_value("user:1", "ok")
	gedis.set_value("user:2", "ok")
	gedis.set_value("foo", "123")
	assert_eq(gedis.exists(["user:1"]), 1, "user:1 should exist")
	assert_eq(gedis.exists(["foo"]), 1, "foo should exist")
	assert_eq(gedis.exists(["nope"]), 0, "nope should not exist")
	var ks = gedis.keys("*")
	assert_eq(ks.size(), 3, "should have 3 keys total")
	assert_eq(gedis.del(["foo"]), 1, "should delete 1 key")
	assert_eq(gedis.exists(["foo"]), 0, "foo should not exist after delete")

func test_getset_key_does_not_exist():
	var result = gedis.getset("key1", "value1")
	assert_eq(result, null)
	assert_eq(gedis.get_value("key1"), "value1")

func test_getset_key_exists():
	gedis.set_value("key1", "value1")
	var result = gedis.getset("key1", "value2")
	assert_eq(result, "value1")
	assert_eq(gedis.get_value("key1"), "value2")

func test_setnx_key_does_not_exist():
	var result = gedis.setnx("key1", "value1")
	assert_eq(result, 1)
	assert_eq(gedis.get_value("key1"), "value1")

func test_setnx_key_exists():
	gedis.set_value("key1", "value1")
	var result = gedis.setnx("key1", "value2")
	assert_eq(result, 0)
	assert_eq(gedis.get_value("key1"), "value1")

func test_rename_key_does_not_exist():
	var result = gedis.rename("key1", "key2")
	assert_eq(result, ERR_DOES_NOT_EXIST)

func test_rename_newkey_exists():
	gedis.set_value("key1", "value1")
	gedis.set_value("key2", "value2")
	var result = gedis.rename("key1", "key2")
	assert_eq(result, 0)
	assert_eq(gedis.get_value("key1"), "value1")
	assert_eq(gedis.get_value("key2"), "value2")

func test_rename_success():
	gedis.set_value("key1", "value1")
	var result = gedis.rename("key1", "key2")
	assert_eq(result, 1)
	assert_eq(gedis.get_value("key1"), null)

func test_move_key_does_not_exist():
	var result = gedis.move("key1", "key2")
	assert_eq(result, ERR_DOES_NOT_EXIST)

func test_move_newkey_exists():
	gedis.set_value("key1", "value1")
	gedis.set_value("key2", "value2")
	var result = gedis.move("key1", "key2")
	assert_eq(result, 1)
	assert_eq(gedis.get_value("key1"), null)
	assert_eq(gedis.get_value("key2"), "value1")

func test_move_success():
	gedis.set_value("key1", "value1")
	var result = gedis.move("key1", "key2")
	assert_eq(result, 1)
	assert_eq(gedis.get_value("key1"), null)
	assert_eq(gedis.get_value("key2"), "value1")
	assert_eq(gedis.get_value("key2"), "value1")


func test_mset_mget():
	gedis.mset({"a": "1", "b": "2", "c": "3"})
	var values = gedis.mget(["a", "b", "c", "missing"])
	assert_eq(values, ["1", "2", "3", null], "mget should return set values and null for missing")

func test_append():
	gedis.set_value("a", "Hello")
	var new_len = gedis.append("a", " World")
	assert_eq(new_len, 11, "append should return the new length of the string")
	assert_eq(gedis.get_value("a"), "Hello World", "append should concatenate the strings")
	assert_eq(gedis.append("missing", "value"), 5, "append on a missing key should create it")

func test_strlen():
	gedis.set_value("a", "Hello")
	assert_eq(gedis.strlen("a"), 5, "strlen should return the length of the string")
	assert_eq(gedis.strlen("missing"), 0, "strlen on a missing key should return 0")
	gedis.set_value("b", 123)
	assert_eq(gedis.strlen("b"), 0, "strlen on a non-string value should return 0")

func test_incrby_decrby():
	gedis.set_value("n", "10")
	assert_eq(gedis.incrby("n", 5), 15, "incrby should increment by the given amount")
	assert_eq(gedis.decrby("n", 5), 10, "decrby should decrement by the given amount")
	assert_eq(gedis.incrby("missing", 5), 5, "incrby on a missing key should start from 0")

func test_randomkey_dbsize():
	assert_eq(gedis.dbsize(), 0, "dbsize should be 0 for an empty database")
	assert_eq(gedis.randomkey(), "", "randomkey should return an empty string for an empty database")
	gedis.set_value("a", "1")
	gedis.set_value("b", "2")
	gedis.set_value("c", "3")
	assert_eq(gedis.dbsize(), 3, "dbsize should return the number of keys")
	var key = gedis.randomkey()
	assert_true(key in ["a", "b", "c"], "randomkey should return a key from the database")

func test_del_method():
	gedis.set_value("a", "1")
	gedis.set_value("b", "2")
	gedis.set_value("c", "3")
	assert_eq(gedis.del("a"), 1, "should delete a single key")
	assert_false(gedis.key_exists("a"), "key 'a' should not exist after deletion")
	assert_eq(gedis.del(["b", "c"]), 2, "should delete multiple keys")
	assert_false(gedis.key_exists("b"), "key 'b' should not exist after deletion")
	assert_false(gedis.key_exists("c"), "key 'c' should not exist after deletion")
	assert_eq(gedis.del("non_existent"), 0, "should return 0 for non-existent key")
	assert_eq(gedis.del(["d", "e"]), 0, "should return 0 for non-existent keys")
