extends GutTest

# A helper class to receive signals
class Subscriber extends Object:
	signal pubsub_message(channel, message)
	signal psub_message(pattern, channel, message)
	
	var received_messages = []
	var received_pmessages = []

	func _on_pubsub_message(channel, message):
		received_messages.append({"channel": channel, "message": message})

	func _on_psub_message(pattern, channel, message):
		received_pmessages.append({"pattern": pattern, "channel": channel, "message": message})

var gedis
var subscriber

func before_each():
	gedis = Gedis.new()
	subscriber = Subscriber.new()
	
	# Connect signals to the subscriber helper - signals are emitted on subscriber objects
	subscriber.connect("pubsub_message", subscriber._on_pubsub_message)
	subscriber.connect("psub_message", subscriber._on_psub_message)

func after_each():
	gedis.free()
	subscriber.free()

func test_subscribe_and_publish():
	var channel = "test_channel"
	var message = "Hello, world!"
	
	gedis.subscribe(channel, subscriber)
	# Yielding to allow the subscribe command to be processed
	await get_tree().create_timer(0.1).timeout
	
	gedis.publish(channel, message)
	# Yielding to allow the message to be received
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(subscriber.received_messages.size(), 1, "Should receive one message")
	if subscriber.received_messages.size() > 0:
		assert_eq(subscriber.received_messages[0].channel, channel, "Channel should match")
		assert_eq(subscriber.received_messages[0].message, message, "Message should match")

func test_unsubscribe():
	var channel = "test_channel"
	var message = "You should not see this"
	
	gedis.subscribe(channel, subscriber)
	await get_tree().create_timer(0.1).timeout
	
	gedis.unsubscribe(channel, subscriber)
	await get_tree().create_timer(0.1).timeout
	
	gedis.publish(channel, message)
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(subscriber.received_messages.size(), 0, "Should not receive any messages after unsubscribing")

func test_psubscribe_and_publish():
	var pattern = "test_pattern:*"
	var channel = "test_pattern:one"
	var message = "Pattern matched!"
	
	gedis.psubscribe(pattern, subscriber)
	await get_tree().create_timer(0.1).timeout
	
	gedis.publish(channel, message)
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(subscriber.received_pmessages.size(), 1, "Should receive one pmessage")
	if subscriber.received_pmessages.size() > 0:
		assert_eq(subscriber.received_pmessages[0].pattern, pattern, "Pattern should match")
		assert_eq(subscriber.received_pmessages[0].channel, channel, "Channel should match")
		assert_eq(subscriber.received_pmessages[0].message, message, "Message should match")

func test_punsubscribe():
	var pattern = "test_pattern:*"
	var channel = "test_pattern:one"
	var message = "You should not see this pmessage"
	
	gedis.psubscribe(pattern, subscriber)
	await get_tree().create_timer(0.1).timeout
	
	gedis.punsubscribe(pattern, subscriber)
	await get_tree().create_timer(0.1).timeout
	
	gedis.publish(channel, message)
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(subscriber.received_pmessages.size(), 0, "Should not receive any pmessages after punsubscribing")