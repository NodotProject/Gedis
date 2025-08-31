extends GutTest

const GEDIS := preload("res://addons/Gedis/gedis.gd")

var g: Gedis
func before_each():
	self.g = GEDIS.new()

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
