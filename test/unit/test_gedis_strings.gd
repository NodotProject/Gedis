extends GutTest

const GEDIS := preload("res://addons/gedis/gedis.gd")

var g
func before_each():
	# Fresh instance per test
	self.g = GEDIS.new()

func test_set_get_and_default():
	g.set_value("a", 1)
	assert_eq(g.get_value("a"), 1, "get should return what was set")
	assert_eq(g.get_value("missing", 42), 42, "get should return default when missing")

func test_incr_decr():
	assert_eq(g.incr("n"), 1)
	assert_eq(g.incr("n", 2), 3)
	assert_eq(g.decr("n", 4), -1)

func test_del_exists_and_keys_glob():
	g.set_value("user:1", "ok")
	g.set_value("user:2", "ok")
	g.set_value("foo", 123)
	assert_true(g.exists("user:1"))
	assert_true(g.exists("foo"))
	assert_false(g.exists("nope"))
	var ks = g.keys("user:?")
	assert_true(ks.has("user:1") && ks.has("user:2") && ks.size() == 2, "glob should match exactly two user keys")
	assert_eq(g.del("foo"), 1)
	assert_false(g.exists("foo"))
