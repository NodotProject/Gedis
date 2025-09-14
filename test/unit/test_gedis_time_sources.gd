extends GutTest

var g

func before_each():
	g = Gedis.new()
	add_child(g)

func after_each():
	g.free()

func test_default_time_source():
	assert_true(g.get_time_source() is GedisUnixTimeSource, "Default time source should be GedisUnixTimeSource")
	g.setex("mykey", 1, "myvalue")
	assert_true(g.ttl("mykey") > 0, "TTL should be greater than 0 with default time source")
	
	var key_expired = false
	for i in 15: # Wait a max of 1.5 seconds
		if not g.key_exists("mykey"):
			key_expired = true
			break
		await get_tree().create_timer(0.1).timeout
	
	assert_true(key_expired, "Key should expire with the default time source")

func test_process_delta_time_source():
	var time_source = GedisProcessDeltaTimeSource.new()
	g.set_time_source(time_source)
	assert_eq(g.get_time_source(), time_source, "Time source should be set to GedisProcessDeltaTimeSource")

	g.setex("mykey", 2, "myvalue") # Expires in 2 seconds of "delta"
	assert_true(g.key_exists("mykey"), "Key should exist immediately after being set")

	time_source._process(1.0)
	g._expiry._purge_expired()
	assert_true(g.key_exists("mykey"), "Key should still exist after 1.0 delta")

	time_source._process(1.0)
	g._expiry._purge_expired()
	assert_false(g.key_exists("mykey"), "Key should be expired after 2.0 delta")

func test_tick_time_source():
	var time_source = GedisTickTimeSource.new()
	g.set_time_source(time_source)
	assert_eq(g.get_time_source(), time_source, "Time source should be set to GedisTickTimeSource")

	g.setex("mykey", 3, "myvalue") # Expires in 3 seconds
	assert_true(g.key_exists("mykey"), "Key should exist immediately after being set")

	# Manually advance time by waiting
	await get_tree().create_timer(3.1).timeout
	g._expiry._purge_expired()
	assert_false(g.key_exists("mykey"), "Key should be expired after 3 seconds")