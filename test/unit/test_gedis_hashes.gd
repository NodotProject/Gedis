extends GutTest

const GEDIS := preload("res://addons/Gedis/gedis.gd")

var g
func before_each():
	self.g = GEDIS.new()

func test_hset_hget_and_default():
	g.hset("h", "a", 10)
	g.hset("h", "b", 20)
	assert_eq(g.hget("h", "a"), 10)
	assert_eq(g.hget("h", "missing", 99), 99)

func test_hdel_and_hgetall():
	g.hset("h", "a", 10)
	g.hset("h", "b", 20)
	assert_eq(g.hdel("h", "a"), 1)
	assert_eq(g.hdel("h", "a"), 0)
	var all = g.hgetall("h")
	assert_eq(all.size(), 1)
	assert_true(all.has("b"))
