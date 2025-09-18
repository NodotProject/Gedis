extends GutTest

var g
var _received_messages = []

func _on_pubsub_message(channel, message):
	_received_messages.append({"channel": channel, "message": message})

func before_each():
	g = Gedis.new()
	add_child(g)
	g.pubsub_message.connect(_on_pubsub_message)
	_received_messages.clear()

func after_each():
	g.pubsub_message.disconnect(_on_pubsub_message)
	remove_child(g)
	g.free()

# TODO: modify this test to test all kinds of keys such as hashes, lists, sorted sets etc
func test_expire_string():
	g.set_value("key", "value")
	assert_true(g.expire("key", 1), "Expire should return true for an existing key")

	# Wait for a maximum of 2 seconds for the key to expire.
	# This is more robust than a fixed timer.
	for i in 20:
		if not g.key_exists("key"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("key"), "Key should not exist after expiry")


func test_expire_hash():
	g.hset("hash_key", "field", "value")
	assert_true(g.expire("hash_key", 1), "Expire should return true for an existing hash key")

	for i in 20:
		if not g.key_exists("hash_key"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("hash_key"), "Hash key should not exist after expiry")


func test_expire_list():
	g.rpush("list_key", ["a", "b", "c"])
	assert_true(g.expire("list_key", 1), "Expire should return true for an existing list key")

	for i in 20:
		if not g.key_exists("list_key"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("list_key"), "List key should not exist after expiry")


func test_expire_set():
	g.sadd("set_key", "member")
	assert_true(g.expire("set_key", 1), "Expire should return true for an existing set key")

	for i in 20:
		if not g.key_exists("set_key"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("set_key"), "Set key should not exist after expiry")


func test_expire_sorted_set():
	g.zadd("sorted_set_key", "member", 1)
	assert_true(g.expire("sorted_set_key", 1), "Expire should return true for an existing sorted set key")

	for i in 20:
		if not g.key_exists("sorted_set_key"):
			break
		await get_tree().create_timer(0.1).timeout

	assert_false(g.key_exists("sorted_set_key"), "Sorted set key should not exist after expiry")

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

func test_an_event_is_published_when_a_key_expires():
	g.subscribe("gedis:keyspace:mykey", self)
	g.setex("mykey", 1, "value")
	await get_tree().create_timer(1.1).timeout
	g._expiry._purge_expired()
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[0].message, "set")
	assert_eq(_received_messages[1].message, "expire")

func test_no_event_is_published_when_a_key_is_persisted():
	g.subscribe("gedis:keyspace:mykey", self)
	g.setex("mykey", 1, "value")
	g.persist("mykey")
	await get_tree().create_timer(1.1).timeout
	g._expiry._purge_expired()
	assert_eq(_received_messages.size(), 1, "Should only receive the set message")
	assert_eq(_received_messages[0].message, "set")
	assert_true(g.key_exists("mykey"), "Key should still exist after being persisted")
