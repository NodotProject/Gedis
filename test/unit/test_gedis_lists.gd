extends GutTest

var g

func before_each():
	self.g = Gedis.new()

func test_lpush_rpush_and_len():
	assert_eq(g.rpush("l", "x"), 1)
	assert_eq(g.lpush("l", "y"), 2)
	assert_eq(g.llen("l"), 2)

func test_lpop_rpop_and_empty():
	g.rpush("l", 1)
	g.rpush("l", 2)
	assert_eq(g.lpop("l"), 1)
	assert_eq(g.rpop("l"), 2)
	assert_eq(g.lpop("l"), null)
	assert_eq(g.rpop("l"), null)


func test_lrange():
	g.rpush("l", 1)
	g.rpush("l", 2)
	g.rpush("l", 3)
	assert_eq(g.lrange("l", 0, 1), [1, 2])
	assert_eq(g.lrange("l", 0, -1), [1, 2, 3])

func test_lindex():
	g.rpush("l", 1)
	g.rpush("l", 2)
	assert_eq(g.lindex("l", 0), 1)
	assert_eq(g.lindex("l", 1), 2)
	assert_eq(g.lindex("l", 2), null)

func test_lset():
	g.rpush("l", 1)
	g.rpush("l", 2)
	g.lset("l", 0, 10)
	assert_eq(g.lindex("l", 0), 10)

func test_lrem():
	g.rpush("l", 1)
	g.rpush("l", 2)
	g.rpush("l", 1)
	g.rpush("l", 1)
	assert_eq(g.lrem("l", 2, 1), 2)
	assert_eq(g.lrange("l", 0, -1), [2, 1])
