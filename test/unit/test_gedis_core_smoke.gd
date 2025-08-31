extends GutTest

# Smoke test for native class GedisCore exposed via GDExtension.
# Validates method add(a, b) for simple cases. No Redis dependency.

var gc

func before_each():
	# Fresh instance per test
	gc = GedisCore.new()

func test_add_two_positive_integers():
	assert_eq(gc.add(2, 3), 5, "2 + 3 should equal 5")

func test_add_two_negative_integers():
	assert_eq(gc.add(-4, -6), -10, "-4 + -6 should equal -10")