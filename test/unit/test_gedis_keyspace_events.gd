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