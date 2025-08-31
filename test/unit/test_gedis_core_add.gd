extends GutTest

# Unit test for Gedis basic functionality
# Tests the basic string operations

var gedis

func before_each():
	# Create a fresh Gedis instance for each test
	gedis = Gedis.new()

func test_set_get_basic():
	# Test: set/get basic functionality
	gedis.set("test", "value")
	assert_eq(gedis.get("test"), "value", "Should retrieve set value")

func test_incr_basic():
	# Test: incr functionality
	gedis.set("counter", 5)
	var result = gedis.incr("counter")
	assert_eq(result, 6, "Incr should increment by 1")

func test_decr_basic():
	# Test: decr functionality
	gedis.set("counter", 10)
	var result = gedis.decr("counter")
	assert_eq(result, 9, "Decr should decrement by 1")