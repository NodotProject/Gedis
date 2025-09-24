extends SceneTree

const ITERATIONS = 10000

func _init():
	var gedis = Gedis.new()
	get_root().add_child(gedis)

	if not is_instance_valid(gedis):
		printerr("Failed to instantiate Gedis.")
		quit(1)

	benchmark_key_expiry(gedis, 1)
	benchmark_key_expiry(gedis, 2)
	benchmark_key_expiry(gedis, 3)
	benchmark_key_expiry(gedis, ITERATIONS)

	gedis.queue_free()
	quit()

func benchmark_key_expiry(gedis: Gedis, multiplier: int):
	var time_source = GedisProcessDeltaTimeSource.new()
	gedis.set_time_source(time_source)

	for i in range(ITERATIONS):
		var key := "key" + str(i)
		gedis.setex(key, i, "value")

	time_source.current_time += (ITERATIONS / multiplier) * 1000

	var start_time = Time.get_ticks_msec()
	gedis._expiry._purge_expired()
	var end_time = Time.get_ticks_msec()

	var elapsed_time = end_time - start_time
	print("benchmark_key_expiry: {0}ms for {1} iterations of {2}".format([elapsed_time, ITERATIONS / multiplier, ITERATIONS]))