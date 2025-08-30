extends GutTest

const GEDIS := preload("res://addons/gedis/gedis.gd")

var g
func before_each():
	self.g = GEDIS.new()

func test_sadd_srem_smembers_sismember():
	assert_eq(g.sadd("s", "a"), 1)
	assert_eq(g.sadd("s", "a"), 0, "second add is no-op")
	assert_true(g.sismember("s", "a"))
	var members = g.smembers("s")
	assert_true(members.has("a"))
	assert_eq(g.srem("s", "a"), 1)
	assert_false(g.sismember("s", "a"))
	assert_eq(g.srem("s", "a"), 0)
