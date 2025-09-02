extends Node

const ITERATIONS = 100000

func _ready():
	run_benchmarks()

func run_benchmarks():
	randomize()
	print("--- Starting Benchmarks ---")

	var results = {}

	# Gedis benchmarks
	var gedis = Gedis.new()
	results["gedis_set"] = benchmark_gedis_set(gedis)
	results["gedis_get"] = benchmark_gedis_get(gedis)
	results["gedis_mset"] = benchmark_gedis_mset(gedis)
	results["gedis_mget"] = benchmark_gedis_mget(gedis)
	results["gedis_keys"] = benchmark_gedis_keys(gedis)

	# GDScript Dictionary benchmarks
	var dict_for_large_kv = {}
	results["dict_set"] = benchmark_dict_set(dict_for_large_kv)
	results["dict_get"] = benchmark_dict_get(dict_for_large_kv)
	results["dict_keys"] = benchmark_dict_keys(dict_for_large_kv)

	var dict_for_m_ops = {}
	results["dict_mset"] = benchmark_dict_mset(dict_for_m_ops)
	results["dict_mget"] = benchmark_dict_mget(dict_for_m_ops)


	print_results(results)

	print("--- Benchmarks Finished ---")
	get_tree().quit()

func print_results(results):
	print("\n--- Benchmark Results ---")
	
	compare_and_print("SET (Large KV)", results.gedis_set, results.dict_set)
	compare_and_print("GET (Large KV)", results.gedis_get, results.dict_get)
	compare_and_print("MSET", results.gedis_mset, results.dict_mset)
	compare_and_print("MGET", results.gedis_mget, results.dict_mget)
	compare_and_print("KEYS (pattern)", results.gedis_keys, results.dict_keys)

func compare_and_print(name, gedis_time, dict_time):
	print("\n%s:" % name)
	print("  Gedis: %s usec" % gedis_time)
	print("  GDScript Dictionary: %s usec" % dict_time)
	if gedis_time > 0 and dict_time > 0:
		if gedis_time < dict_time:
			print("  Gedis is %.2fx faster" % [float(dict_time) / gedis_time])
		else:
			print("  GDScript Dictionary is %.2fx faster" % [float(gedis_time) / dict_time])

func benchmark_gedis_set(gedis_instance):
	var start_time = Time.get_ticks_usec()
	var d = {}
	for i in range(ITERATIONS):
		d["key" + str(i)] = "value" + str(i)
	gedis_instance.set("large_key", d)
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_gedis_get(gedis_instance: Gedis):
	var d = {}
	for i in range(ITERATIONS):
		d["key" + str(i)] = "value" + str(i)
	# Populate Gedis with individual top-level keys for per-key GET testing
	gedis_instance.mset(d)

	var random_index = randi() % ITERATIONS
	var key = "key" + str(random_index)

	var start_time = Time.get_ticks_usec()
	gedis_instance.get(key)
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_dict_set(dict_instance):
	var start_time = Time.get_ticks_usec()
	var d = {}
	for i in range(ITERATIONS):
		d["key" + str(i)] = "value" + str(i)
	dict_instance["large_key"] = d
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_dict_get(dict_instance: Dictionary):
	# Populate dict_instance with individual top-level keys for per-key GET testing
	for i in range(ITERATIONS):
		dict_instance["key" + str(i)] = "value" + str(i)

	var random_index = randi() % ITERATIONS
	var key = "key" + str(random_index)

	var start_time = Time.get_ticks_usec()
	var value = dict_instance[key]
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_gedis_mset(gedis_instance):
	var d = {}
	for i in range(ITERATIONS):
		d["key" + str(i)] = "value" + str(i)
	var start_time = Time.get_ticks_usec()
	gedis_instance.mset(d)
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_gedis_mget(gedis_instance):
	var keys = []
	for i in range(ITERATIONS):
		keys.append("key" + str(i))
	var start_time = Time.get_ticks_usec()
	gedis_instance.mget(keys)
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_dict_mset(dict_instance):
	var d = {}
	for i in range(ITERATIONS):
		d["key" + str(i)] = "value" + str(i)
	var start_time = Time.get_ticks_usec()
	for key in d:
		dict_instance[key] = d[key]
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_dict_mget(dict_instance):
	var keys = []
	for i in range(ITERATIONS):
		keys.append("key" + str(i))
	var start_time = Time.get_ticks_usec()
	for key in keys:
		var value = dict_instance[key]
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_dict_keys(dict_instance: Dictionary):
	# Populate dict_instance with top-level keys and measure pattern lookup
	for i in range(ITERATIONS):
		dict_instance["key" + str(i)] = "value" + str(i)
	var start_time = Time.get_ticks_usec()
	var matches = []
	# Use RegEx to match the 'key*' pattern (prefix 'key')
	var regex = RegEx.new()
	if regex.compile("^key.*") != OK:
		# Fallback to prefix check if regex compile fails
		for k in dict_instance.keys():
			if k.substr(0, 3) == "key":
				matches.append(k)
	else:
		for k in dict_instance.keys():
			if regex.search(k) != null:
				matches.append(k)
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed

func benchmark_gedis_keys(gedis_instance: Gedis):
	var d = {}
	for i in range(ITERATIONS):
		d["key" + str(i)] = "value" + str(i)
	# Populate the Gedis instance with the keys
	gedis_instance.mset(d)
	var start_time = Time.get_ticks_usec()
	gedis_instance.keys("key*")
	var end_time = Time.get_ticks_usec()
	var elapsed = end_time - start_time
	return elapsed
