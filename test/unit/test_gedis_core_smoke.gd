extends GutTest

# Smoke test for native Gedis class exposed via GDExtension.
# Validates basic functionality. No Redis dependency.

var gedis

func before_each():
	# Fresh instance per test
	gedis = Gedis.new()

func test_basic_set_get():
	gedis.set("key1", "value1")
	assert_eq(gedis.get("key1"), "value1", "Should get what was set")

func test_keys_pattern():
	gedis.set("test:1", "a")
	gedis.set("test:2", "b")
	var keys = gedis.keys("test:*")
	assert_eq(keys.size(), 2, "Should find 2 keys matching pattern")