extends GutTest

var g

func before_each():
	self.g = Gedis.new()

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


func test_hkeys():
	g.hset("h", "a", 10)
	g.hset("h", "b", 20)
	var keys = g.hkeys("h")
	assert_eq(keys.size(), 2)
	assert_true(keys.has("a"))
	assert_true(keys.has("b"))

func test_hvals():
	g.hset("h", "a", 10)
	g.hset("h", "b", 20)
	var vals = g.hvals("h")
	assert_eq(vals.size(), 2)
	assert_true(vals.has(10))
	assert_true(vals.has(20))

func test_hexists():
	g.hset("h", "a", 10)
	assert_true(g.hexists("h", "a"))
	assert_false(g.hexists("h", "b"))

func test_hlen():
	g.hset("h", "a", 10)
	g.hset("h", "b", 20)
	assert_eq(g.hlen("h"), 2)
