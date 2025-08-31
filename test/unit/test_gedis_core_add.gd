extends GutTest

# Unit test for GedisCore.add method
# Tests the basic addition functionality with various integer inputs

var gedis_core

func before_each():
	# Create a fresh GedisCore instance for each test
	gedis_core = GedisCore.new()

func test_add_positive_integers():
	# Test: add(1, 2) == 3
	assert_eq(gedis_core.add(1, 2), 3, "1 + 2 should equal 3")

func test_add_negative_and_positive():
	# Test: add(-5, 5) == 0
	assert_eq(gedis_core.add(-5, 5), 0, "-5 + 5 should equal 0")

func test_add_zeros():
	# Test: add(0, 0) == 0
	assert_eq(gedis_core.add(0, 0), 0, "0 + 0 should equal 0")