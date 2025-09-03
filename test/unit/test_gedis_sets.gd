extends GutTest

var g

func before_each():
	self.g = Gedis.new()

func after_each():
	g.free()

func test_sadd_srem_smembers_sismember():
	assert_eq(g.sadd("s", "a"), 1)
	assert_eq(g.sadd("s", "a"), 0, "second add is no-op")
	assert_true(g.sismember("s", "a"))
	var members = g.smembers("s")
	assert_true(members.has("a"))
	assert_eq(g.srem("s", "a"), 1)
	assert_false(g.sismember("s", "a"))
	assert_eq(g.srem("s", "a"), 0)


func test_scard():
	g.sadd("s", "a")
	g.sadd("s", "b")
	assert_eq(g.scard("s"), 2)

func test_spop():
	g.sadd("s", "a")
	g.sadd("s", "b")
	var popped = g.spop("s")
	assert_true(popped == "a" or popped == "b")
	assert_eq(g.scard("s"), 1)

func test_smove():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "c")
	assert_true(g.smove("s1", "s2", "a"))
	assert_false(g.sismember("s1", "a"))
	assert_true(g.sismember("s2", "a"))
