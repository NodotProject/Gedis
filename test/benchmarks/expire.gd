extends SceneTree

const ITERATIONS = 10000

func _init():
	var gedis = Gedis.new()
	get_root().add_child(gedis)

	if not is_instance_valid(gedis):
		printerr("Failed to instantiate Gedis.")
		quit(1)

	benchmark_key_expiry(gedis)

	gedis.queue_free()
	quit()

func benchmark_key_expiry(gedis: Gedis):
	var time_source = load("res://test/benchmarks/manual_time_source.gd").new()
	gedis.set_time_source(time_source)

	for i in range(ITERATIONS):
		var key := "key" + str(i)
		gedis.set_value(key, "value")
		gedis.expire(key, 10 + i)

	# Advance time past the expiry point of all keys
	time_source.advance_time((10 + ITERATIONS) * 1000)

	var start_time := Time.get_ticks_msec()
	gedis._expiry._purge_expired()
	var end_time := Time.get_ticks_msec()

	var elapsed_time = end_time - start_time
	print("benchmark_key_expiry: {0}ms for {1} iterations".format([elapsed_time, ITERATIONS]))