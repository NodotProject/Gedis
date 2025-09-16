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

func test_incr_decr():
	assert_eq(gedis.incr("n"), 1, "incr on non-existent key should return 1")
	assert_eq(gedis.incr("n"), 2, "incr should increment existing value")
	assert_eq(gedis.decr("n"), 1, "decr should decrement existing value")

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
