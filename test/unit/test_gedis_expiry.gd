extends GutTest

const GEDIS := preload("res://addons/gedis/gedis.gd")

func before_each():
	self.g = GEDIS.new()

func test_expire_ttl_and_eviction():
	g.set("k", "v")
	assert_true(g.expire("k", 1))
	var t := g.ttl("k")
	assert_true(t == 0 || t == 1, "ttl should be 0 or 1 just after setting 1s expiry")
	OS.delay_msec(1200) # wait for expiry
	assert_false(g.exists("k"))
	assert_eq(g.get("k", "missing"), "missing")

func test_persist_and_flushall():
	g.set("a", 1)
	g.set("b", 2)
	g.expire("a", 10)
	assert_true(g.persist("a"))
	assert_eq(g.ttl("a"), -1)
	g.flushall()
	assert_false(g.exists("a"))
	assert_false(g.exists("b"))
