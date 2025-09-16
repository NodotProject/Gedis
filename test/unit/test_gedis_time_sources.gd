extends GutTest

var gedis = null

class MockTimeSource extends GedisTimeSource:
	var time = 0
	func get_time():
		return time

func before_all():
	gedis = Gedis.new()
	add_child(gedis)

func after_all():
	remove_child(gedis)
	gedis.free()

func before_each():
	gedis.flushdb()
	# Reset to default time source before each test
	gedis.set_time_source(GedisUnixTimeSource.new())

func test_get_time_source_default():
	var default_time_source = gedis.get_time_source()
	assert_true(default_time_source is GedisUnixTimeSource, "Default time source should be GedisUnixTimeSource")

func test_set_and_get_time_source():
	var mock_time_source = MockTimeSource.new()
	mock_time_source.time = 12345
	
	gedis.set_time_source(mock_time_source)
	var current_time_source = gedis.get_time_source()
	
	assert_eq(current_time_source, mock_time_source, "get_time_source should return the mock time source")
	assert_eq(current_time_source.get_time(), 12345, "Mock time source should return the set time")
