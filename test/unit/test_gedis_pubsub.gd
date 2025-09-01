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

func test_psubscribe_multiple_patterns():
	var pattern1 = "test_pattern:*"
	var pattern2 = "another_pattern:*"
	var channel1 = "test_pattern:one"
	var channel2 = "another_pattern:two"
	var message1 = "Pattern 1 matched!"
	var message2 = "Pattern 2 matched!"

	gedis.psubscribe(pattern1, subscriber)
	gedis.psubscribe(pattern2, subscriber)
	await get_tree().create_timer(0.1).timeout

	gedis.publish(channel1, message1)
	gedis.publish(channel2, message2)
	await get_tree().create_timer(0.1).timeout

	assert_eq(subscriber.received_pmessages.size(), 2, "Should receive two pmessages")

	gedis.punsubscribe(pattern1, subscriber)
	await get_tree().create_timer(0.1).timeout

	gedis.publish(channel1, "This should not be received")
	gedis.publish(channel2, "This should be received")
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(subscriber.received_pmessages.size(), 3, "Should have received one more pmessage")
	assert_eq(subscriber.received_pmessages[2].channel, channel2, "The channel of the last message should be from the still subscribed pattern")