extends "res://addons/gut/test.gd"

var gedis

func before_each():
	gedis = Gedis.new()
	gedis.flushall()

func after_each():
	gedis.free()

func test_lmove_left_to_left():
	gedis.rpush("source", ["one", "two", "three"])
	gedis.rpush("destination", ["four", "five", "six"])
	var result = gedis.lmove("source", "destination", "LEFT", "LEFT")
	assert_eq(result, "one", "LMOVE should return the moved element")
	assert_eq(gedis.lrange("source", 0, -1), ["two", "three"], "Source list should be correct")
	assert_eq(gedis.lrange("destination", 0, -1), ["one", "four", "five", "six"], "Destination list should be correct")

func test_lmove_left_to_right():
	gedis.rpush("source", ["one", "two", "three"])
	gedis.rpush("destination", ["four", "five", "six"])
	var result = gedis.lmove("source", "destination", "LEFT", "RIGHT")
	assert_eq(result, "one", "LMOVE should return the moved element")
	assert_eq(gedis.lrange("source", 0, -1), ["two", "three"], "Source list should be correct")
	assert_eq(gedis.lrange("destination", 0, -1), ["four", "five", "six", "one"], "Destination list should be correct")

func test_lmove_right_to_left():
	gedis.rpush("source", ["one", "two", "three"])
	gedis.rpush("destination", ["four", "five", "six"])
	var result = gedis.lmove("source", "destination", "RIGHT", "LEFT")
	assert_eq(result, "three", "LMOVE should return the moved element")
	assert_eq(gedis.lrange("source", 0, -1), ["one", "two"], "Source list should be correct")
	assert_eq(gedis.lrange("destination", 0, -1), ["three", "four", "five", "six"], "Destination list should be correct")

func test_lmove_right_to_right():
	gedis.rpush("source", ["one", "two", "three"])
	gedis.rpush("destination", ["four", "five", "six"])
	var result = gedis.lmove("source", "destination", "RIGHT", "RIGHT")
	assert_eq(result, "three", "LMOVE should return the moved element")
	assert_eq(gedis.lrange("source", 0, -1), ["one", "two"], "Source list should be correct")
	assert_eq(gedis.lrange("destination", 0, -1), ["four", "five", "six", "three"], "Destination list should be correct")

func test_lmove_from_empty_source():
	gedis.rpush("destination", ["one", "two", "three"])
	var result = gedis.lmove("source", "destination", "LEFT", "LEFT")
	assert_null(result, "LMOVE from empty source should return null")
	assert_eq(gedis.llen("destination"), 3, "Destination list should not be modified")

func test_lmove_to_non_existent_destination():
	gedis.rpush("source", ["one", "two", "three"])
	var result = gedis.lmove("source", "new_destination", "LEFT", "LEFT")
	assert_eq(result, "one", "LMOVE should return the moved element")
	assert_eq(gedis.lrange("source", 0, -1), ["two", "three"], "Source list should be correct")
	assert_eq(gedis.lrange("new_destination", 0, -1), ["one"], "New destination list should be created")