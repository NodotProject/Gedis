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
	remove_child(g)
	g.free()
	
func test_adding_keyspace_prefix_to_key():
	assert_eq(g.ks("test"), "gedis:keyspace:test")
	
func test_remove_keyspace_prefix_from_key():
	assert_eq(g.rks("gedis:keyspace:test"), "test")

func test_rks_does_nothing_when_prefix_not_present():
	# Should return the original key when keyspace prefix is not present
	assert_eq(g.rks("normal_key"), "normal_key")
	assert_eq(g.rks("another:prefix:key"), "another:prefix:key")
	assert_eq(g.rks("gedis:different:key"), "gedis:different:key")
	
func test_rks_handles_edge_cases():
	# Should handle short keys correctly
	assert_eq(g.rks("short"), "short")
	assert_eq(g.rks("a"), "a")
	
	# Should handle empty key correctly  
	assert_eq(g.rks(""), "")
	
	# Should handle keys that partially match the prefix
	assert_eq(g.rks("gedis:key"), "gedis:key")
	assert_eq(g.rks("gedis:keyspace"), "gedis:keyspace")
	
	# Should handle exact prefix (edge case)
	assert_eq(g.rks("gedis:keyspace:"), "")

func test_set_event_is_published():
	g.subscribe("gedis:keyspace:mykey", self)
	g.set_value("mykey", "value")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].channel, "gedis:keyspace:mykey")
	assert_eq(_received_messages[0].message, "set")

func test_del_event_is_published():
	g.subscribe("gedis:keyspace:mykey", self)
	g.set_value("mykey", "value")
	g.del("mykey")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2) # set and del
	assert_eq(_received_messages[1].channel, "gedis:keyspace:mykey")
	assert_eq(_received_messages[1].message, "del")

func test_del_event_is_not_published_for_nonexistent_key():
	g.subscribe("gedis:keyspace:mykey", self)
	g.del("mykey")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 0)

func test_incrby_publishes_set_event():
	g.subscribe("gedis:keyspace:mykey", self)
	g.incrby("mykey")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].channel, "gedis:keyspace:mykey")
	assert_eq(_received_messages[0].message, "set")

func test_sadd_publishes_set_event():
	g.subscribe("gedis:keyspace:myset", self)
	g.sadd("myset", "member")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].channel, "gedis:keyspace:myset")
	assert_eq(_received_messages[0].message, "set")

func test_srem_publishes_del_event_when_set_becomes_empty():
	g.subscribe("gedis:keyspace:myset", self)
	g.sadd("myset", "member")
	g.srem("myset", "member")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].channel, "gedis:keyspace:myset")
	assert_eq(_received_messages[1].message, "del")

func test_spop_publishes_del_event_when_set_becomes_empty():
	g.subscribe("gedis:keyspace:myset", self)
	g.sadd("myset", "member")
	g.spop("myset")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].channel, "gedis:keyspace:myset")
	assert_eq(_received_messages[1].message, "del")

func test_hset_publishes_set_event():
	g.subscribe("gedis:keyspace:myhash", self)
	g.hset("myhash", "field", "value")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_hmset_publishes_set_event():
	g.subscribe("gedis:keyspace:myhash", self)
	g.hmset("myhash", {"field1": "value1", "field2": "value2"})
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_hincrby_publishes_set_event():
	g.subscribe("gedis:keyspace:myhash", self)
	g.hincrby("myhash", "field", 1)
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_hincrbyfloat_publishes_set_event():
	g.subscribe("gedis:keyspace:myhash", self)
	g.hincrbyfloat("myhash", "field", 1.5)
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_hdel_publishes_del_event_when_hash_becomes_empty():
	g.subscribe("gedis:keyspace:myhash", self)
	g.hset("myhash", "field", "value")
	g.hdel("myhash", "field")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].message, "del")

func test_lpush_publishes_set_event():
	g.subscribe("gedis:keyspace:mylist", self)
	g.lpush("mylist", "value")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_rpush_publishes_set_event():
	g.subscribe("gedis:keyspace:mylist", self)
	g.rpush("mylist", "value")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_lpop_publishes_set_and_del_events():
	g.subscribe("gedis:keyspace:mylist", self)
	g.lpush("mylist", "value1")
	g.lpush("mylist", "value2")
	g.lpop("mylist") # set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 3)
	assert_eq(_received_messages[2].message, "set")
	g.lpop("mylist") # del
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 4)
	assert_eq(_received_messages[3].message, "del")

func test_rpop_publishes_set_and_del_events():
	g.subscribe("gedis:keyspace:mylist", self)
	g.rpush("mylist", "value1")
	g.rpush("mylist", "value2")
	g.rpop("mylist") # set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 3)
	assert_eq(_received_messages[2].message, "set")
	g.rpop("mylist") # del
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 4)
	assert_eq(_received_messages[3].message, "del")

func test_lset_publishes_set_event():
	g.subscribe("gedis:keyspace:mylist", self)
	g.lpush("mylist", "value")
	g.lset("mylist", 0, "new_value")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].message, "set")

func test_linsert_publishes_set_event():
	g.subscribe("gedis:keyspace:mylist", self)
	g.lpush("mylist", "value")
	g.linsert("mylist", "BEFORE", "value", "new_value")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].message, "set")

func test_ltrim_publishes_set_and_del_events():
	g.subscribe("gedis:keyspace:mylist", self)
	g.lpush("mylist", "value1")
	g.lpush("mylist", "value2")
	g.ltrim("mylist", 0, 0) # set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 3)
	assert_eq(_received_messages[2].message, "set")
	g.ltrim("mylist", 1, 0) # del
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 4)
	assert_eq(_received_messages[3].message, "del")

func test_lrem_publishes_set_and_del_events():
	g.subscribe("gedis:keyspace:mylist", self)
	g.lpush("mylist", "value1")
	g.lpush("mylist", "value2")
	g.lpush("mylist", "value1")
	g.lrem("mylist", 1, "value1") # set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 4)
	assert_eq(_received_messages[3].message, "set")
	g.lrem("mylist", 0, "value2") # set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 5)
	assert_eq(_received_messages[4].message, "set")
	g.lrem("mylist", 1, "value1") # del
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 6)
	assert_eq(_received_messages[5].message, "del")

func test_lmove_publishes_set_and_del_events():
	g.subscribe("gedis:keyspace:mylist1", self)
	g.subscribe("gedis:keyspace:mylist2", self)
	g.lpush("mylist1", "one")
	g.lpush("mylist1", "two")
	g.lmove("mylist1", "mylist2", "LEFT", "RIGHT") # mylist1: set, mylist2: set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 4)
	assert_eq(_received_messages[2].channel, "gedis:keyspace:mylist1")
	assert_eq(_received_messages[2].message, "set")
	assert_eq(_received_messages[3].channel, "gedis:keyspace:mylist2")
	assert_eq(_received_messages[3].message, "set")
	g.lmove("mylist1", "mylist2", "LEFT", "RIGHT") # mylist1: del, mylist2: set
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 6)
	assert_eq(_received_messages[4].channel, "gedis:keyspace:mylist1")
	assert_eq(_received_messages[4].message, "del")
	assert_eq(_received_messages[5].channel, "gedis:keyspace:mylist2")
	assert_eq(_received_messages[5].message, "set")

func test_zadd_publishes_set_event():
	g.subscribe("gedis:keyspace:myzset", self)
	g.zadd("myzset", "member", 1)
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")

func test_zincrby_publishes_set_event():
	g.subscribe("gedis:keyspace:myzset", self)
	g.zincrby("myzset", 1, "member")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 1)
	assert_eq(_received_messages[0].message, "set")


func test_zinterstore_publishes_del_and_set_events():
	g.zadd("zset1", "a", 1)
	g.zadd("zset2", "a", 2)
	g.zadd("dest", "c", 3)
	g.subscribe("gedis:keyspace:dest", self)
	g.zinterstore("dest", ["zset1", "zset2"])
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 3)
	assert_eq(_received_messages[0].message, "set")
	assert_eq(_received_messages[1].message, "del")
	assert_eq(_received_messages[2].message, "set")

func test_zrem_publishes_del_event_when_sorted_set_becomes_empty():
	g.subscribe("gedis:keyspace:myzset", self)
	g.zadd("myzset", "member", 1)
	g.zrem("myzset", "member")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].message, "del")

func test_zpop_ready_publishes_del_event_when_sorted_set_becomes_empty():
	g.subscribe("gedis:keyspace:myzset", self)
	g.zadd("myzset", "member", 1)
	g.zpopready("myzset", 2)
	await get_tree().create_timer(0.1).timeout
	assert_eq(_received_messages.size(), 2)
	assert_eq(_received_messages[1].message, "del")
