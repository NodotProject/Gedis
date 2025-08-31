extends GutTest

var gedis

func before_each():
	# Fresh instance per test
	gedis = Gedis.new()

func test_set_get():
	gedis.set("a", "1")
	assert_eq(gedis.get("a"), "1", "get should return what was set")
	assert_eq(gedis.get("missing"), null, "get should return null when missing")

func test_incr_decr():
	assert_eq(gedis.incr("n"), 1, "incr on non-existent key should return 1")
	assert_eq(gedis.incr("n"), 2, "incr should increment existing value")
	assert_eq(gedis.decr("n"), 1, "decr should decrement existing value")

func test_del_exists_and_keys():
	gedis.set("user:1", "ok")
	gedis.set("user:2", "ok")
	gedis.set("foo", "123")
	assert_eq(gedis.exists(["user:1"]), 1, "user:1 should exist")
	assert_eq(gedis.exists(["foo"]), 1, "foo should exist")
	assert_eq(gedis.exists(["nope"]), 0, "nope should not exist")
	var ks = gedis.keys("*")
	assert_eq(ks.size(), 3, "should have 3 keys total")
	assert_eq(gedis.del(["foo"]), 1, "should delete 1 key")
	assert_eq(gedis.exists(["foo"]), 0, "foo should not exist after delete")
