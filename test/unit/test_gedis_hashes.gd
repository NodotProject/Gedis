extends GutTest

var gedis = null

func before_all():
	gedis = Gedis.new()
	gedis.flushdb()

func after_all():
	gedis.free()

func before_each():
	gedis.flushdb()

func test_hincrby_field_does_not_exist():
	gedis.hset("key1", "field1", 10)
	var result = gedis.hincrby("key1", "field2", 5)
	assert_eq(result, 5)
	assert_eq(gedis.hget("key1", "field2"), 5)

func test_hincrby_field_exists():
	gedis.hset("key1", "field1", 10)
	var result = gedis.hincrby("key1", "field1", 5)
	assert_eq(result, 15)
	assert_eq(gedis.hget("key1", "field1"), 15)

func test_hincrbyfloat_field_does_not_exist():
	gedis.hset("key1", "field1", 10.5)
	var result = gedis.hincrbyfloat("key1", "field2", 5.5)
	assert_eq(result, 5.5)
	assert_eq(gedis.hget("key1", "field2"), 5.5)

func test_hincrbyfloat_field_exists():
	gedis.hset("key1", "field1", 10.5)
	var result = gedis.hincrbyfloat("key1", "field1", 5.5)
	assert_eq(result, 16.0)
	assert_eq(gedis.hget("key1", "field1"), 16.0)
