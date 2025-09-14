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

func test_list_channels():
	gedis.subscribe("channel1", subscriber)
	gedis.subscribe("channel2", subscriber)
	var channels = gedis.list_channels()
	assert_eq(channels.size(), 2, "Should list two channels")
	assert_has(channels, "channel1", "Should contain channel1")
	assert_has(channels, "channel2", "Should contain channel2")

func test_list_subscribers():
	var subscriber2 = Subscriber.new()
	gedis.subscribe("channel1", subscriber)
	gedis.subscribe("channel1", subscriber2)
	var subscribers = gedis.list_subscribers("channel1")
	assert_eq(subscribers.size(), 2, "Should list two subscribers for channel1")
	assert_has(subscribers, subscriber, "Should contain subscriber")
	assert_has(subscribers, subscriber2, "Should contain subscriber2")
	subscriber2.free()

func test_list_patterns():
	gedis.psubscribe("pattern:*", subscriber)
	gedis.psubscribe("another_pattern:*", subscriber)
	var patterns = gedis.list_patterns()
	assert_eq(patterns.size(), 2, "Should list two patterns")
	assert_has(patterns, "pattern:*", "Should contain pattern:*")
	assert_has(patterns, "another_pattern:*", "Should contain another_pattern:*")

func test_list_pattern_subscribers():
	var subscriber2 = Subscriber.new()
	gedis.psubscribe("pattern:*", subscriber)
	gedis.psubscribe("pattern:*", subscriber2)
	var subscribers = gedis.list_pattern_subscribers("pattern:*")
	assert_eq(subscribers.size(), 2, "Should list two subscribers for pattern:*")
	assert_has(subscribers, subscriber, "Should contain subscriber")
	assert_has(subscribers, subscriber2, "Should contain subscriber2")
	subscriber2.free()

func test_subscribe_signal():
	watch_signals(gedis._pubsub)
	gedis.subscribe("channel1", subscriber)
	assert_signal_emitted_with_parameters(gedis._pubsub, "subscribed", ["channel1", subscriber])

func test_unsubscribe_signal():
	watch_signals(gedis._pubsub)
	gedis.subscribe("channel1", subscriber)
	gedis.unsubscribe("channel1", subscriber)
	assert_signal_emitted_with_parameters(gedis._pubsub, "unsubscribed", ["channel1", subscriber])

func test_gedis_level_pubsub_signal():
	var channel = "test_channel"
	var message = "Hello, Gedis!"
	
	# Connect directly to the Gedis instance signal
	gedis.pubsub_message.connect(subscriber._on_pubsub_message)
	
	var dummy_subscriber = Object.new()
	gedis.subscribe(channel, dummy_subscriber)
	gedis.publish(channel, message)
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(subscriber.received_messages.size(), 1, "Should receive one message on Gedis signal")
	assert_eq(subscriber.received_messages[0].channel, channel)
	assert_eq(subscriber.received_messages[0].message, message)

	gedis.pubsub_message.disconnect(subscriber._on_pubsub_message)

func test_gedis_level_psub_signal():
	var pattern = "test:*"
	var channel = "test:channel"
	var message = "Hello, psub Gedis!"

	# Connect directly to the Gedis instance signal
	gedis.psub_message.connect(subscriber._on_psub_message)

	var dummy_subscriber = Object.new()
	gedis.psubscribe(pattern, dummy_subscriber)
	gedis.publish(channel, message)
	await get_tree().create_timer(0.1).timeout

	assert_eq(subscriber.received_pmessages.size(), 1, "Should receive one pmessage on Gedis signal")
	assert_eq(subscriber.received_pmessages[0].pattern, pattern)
	assert_eq(subscriber.received_pmessages[0].channel, channel)
	assert_eq(subscriber.received_pmessages[0].message, message)

	gedis.psub_message.disconnect(subscriber._on_psub_message)
