extends GutTest

var g

func before_each():
	g = Gedis.new()

func after_each():
	g.free()

func test_expire():
	g.set_value("key", "value")
	assert_true(g.expire("key", 1), "Expire should return true for an existing key")

	# Wait for a maximum of 2 seconds for the key to expire.
	# This is more robust than a fixed timer.
	for i in 20:
		if not g.key_exists("key"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("key"), "Key should not exist after expiry")

func test_ttl_with_expiry():
	g.set_value("key", "value")
	g.expire("key", 2)
	var ttl = g.ttl("key")
	assert_true(ttl > 0 and ttl <= 2, "TTL should be between 0 and 2")

func test_ttl_without_expiry():
	g.set_value("key", "value")
	assert_eq(g.ttl("key"), -1, "TTL should be -1 for a key with no expiry")

func test_ttl_for_nonexistent_key():
	assert_eq(g.ttl("nonexistent"), -2, "TTL should be -2 for a nonexistent key")

func test_persist():
	g.set_value("key", "value")
	g.expire("key", 5)
	assert_true(g.persist("key"), "Persist should return true for a key with an expiry")
	assert_eq(g.ttl("key"), -1, "TTL should be -1 after persist")

func test_persist_on_non_expiring_key():
	g.set_value("key", "value")
	assert_false(g.persist("key"), "Persist should return false for a key without an expiry")

func test_persist_on_nonexistent_key():
	assert_false(g.persist("nonexistent"), "Persist should return false for a nonexistent key")

func test_setex():
	g.setex("mykey", 2, "myvalue")
	assert_eq(g.get_value("mykey"), "myvalue", "Value should be set correctly")
	var ttl = g.ttl("mykey")
	assert_true(ttl > 0 and ttl <= 2, "TTL should be set correctly")

	# Wait for expiry
	for i in 25: # 2.5 seconds max wait
		if not g.key_exists("mykey"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("mykey"), "Key should expire after the given time")
