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

func test_sunion():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "b")
	g.sadd("s2", "c")
	var result = g.sunion(["s1", "s2"])
	assert_eq(result.size(), 3)
	assert_true(result.has("a"))
	assert_true(result.has("b"))
	assert_true(result.has("c"))

func test_sinter():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "b")
	g.sadd("s2", "c")
	var result = g.sinter(["s1", "s2"])
	assert_eq(result.size(), 1)
	assert_true(result.has("b"))

func test_sdiff():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "b")
	g.sadd("s2", "c")
	var result = g.sdiff(["s1", "s2"])
	assert_eq(result.size(), 1)
	assert_true(result.has("a"))

func test_sunionstore():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "b")
	g.sadd("s2", "c")
	var count = g.sunionstore("dest", ["s1", "s2"])
	assert_eq(count, 3)
	var members = g.smembers("dest")
	assert_eq(members.size(), 3)
	assert_true(members.has("a"))
	assert_true(members.has("b"))
	assert_true(members.has("c"))

func test_sinterstore():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "b")
	g.sadd("s2", "c")
	var count = g.sinterstore("dest", ["s1", "s2"])
	assert_eq(count, 1)
	var members = g.smembers("dest")
	assert_eq(members.size(), 1)
	assert_true(members.has("b"))

func test_sdiffstore():
	g.sadd("s1", "a")
	g.sadd("s1", "b")
	g.sadd("s2", "b")
	g.sadd("s2", "c")
	var count = g.sdiffstore("dest", ["s1", "s2"])
	assert_eq(count, 1)
	var members = g.smembers("dest")
	assert_eq(members.size(), 1)
	assert_true(members.has("a"))

func test_srandmember():
	g.sadd("s", "a")
	g.sadd("s", "b")
	g.sadd("s", "c")
	var member = g.srandmember("s")
	assert_true(g.sismember("s", member))

	var members = g.srandmember("s", 2)
	assert_eq(members.size(), 2)
	assert_true(g.sismember("s", members[0]))
	assert_true(g.sismember("s", members[1]))
	assert_ne(members[0], members[1])

	members = g.srandmember("s", -5)
	assert_eq(members.size(), 5)
