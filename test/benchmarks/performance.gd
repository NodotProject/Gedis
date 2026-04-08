extends SceneTree

const SMALL = 100
const MEDIUM = 1000
const LARGE = 5000

func _init():
	var gedis = Gedis.new()
	get_root().add_child(gedis)

	if not is_instance_valid(gedis):
		printerr("Failed to instantiate Gedis.")
		quit(1)

	print("=== Gedis Performance Benchmarks ===\n")

	bench_sorted_set_add(gedis)
	bench_sorted_set_add_update(gedis)
	bench_sorted_set_zrank(gedis)
	bench_sorted_set_zcount(gedis)
	bench_sorted_set_zrangebyscore(gedis)
	bench_sorted_set_zrevrange(gedis)
	bench_touch_type_existing_key(gedis)
	bench_touch_type_new_key(gedis)
	bench_key_exists(gedis)
	bench_get_all_keys(gedis)
	bench_dbsize(gedis)
	bench_sinter(gedis)
	bench_list_lpop(gedis)
	bench_list_rpop(gedis)
	bench_list_lset(gedis)
	bench_publish_with_pattern_subscribers(gedis)
	bench_publish_with_direct_subscribers(gedis)
	bench_delete_all_types(gedis)

	gedis.queue_free()
	quit()


# --- Sorted Set Benchmarks ---

func bench_sorted_set_add(gedis: Gedis):
	gedis.flushall()
	var start = Time.get_ticks_usec()
	for i in range(LARGE):
		gedis.zadd("zset", "member_%d" % i, i)
	var elapsed = Time.get_ticks_usec() - start
	print("sorted_set_add: %d members inserted in %dms" % [LARGE, elapsed / 1000])
	gedis.flushall()

func bench_sorted_set_add_update(gedis: Gedis):
	gedis.flushall()
	# Pre-populate
	for i in range(MEDIUM):
		gedis.zadd("zset", "member_%d" % i, i)
	# Benchmark updating existing members
	var start = Time.get_ticks_usec()
	for i in range(MEDIUM):
		gedis.zadd("zset", "member_%d" % i, MEDIUM - i)
	var elapsed = Time.get_ticks_usec() - start
	print("sorted_set_add_update: %d members updated in %dms" % [MEDIUM, elapsed / 1000])
	gedis.flushall()

func bench_sorted_set_zrank(gedis: Gedis):
	gedis.flushall()
	for i in range(MEDIUM):
		gedis.zadd("zset", "member_%d" % i, i)
	var iterations = SMALL
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		gedis.zrank("zset", "member_%d" % (i * 10))
	var elapsed = Time.get_ticks_usec() - start
	print("sorted_set_zrank: %d lookups in %dms (set size %d)" % [iterations, elapsed / 1000, MEDIUM])
	gedis.flushall()

func bench_sorted_set_zcount(gedis: Gedis):
	gedis.flushall()
	for i in range(MEDIUM):
		gedis.zadd("zset", "member_%d" % i, i)
	var iterations = SMALL
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		gedis.zcount("zset", i, i + 100)
	var elapsed = Time.get_ticks_usec() - start
	print("sorted_set_zcount: %d range counts in %dms (set size %d)" % [iterations, elapsed / 1000, MEDIUM])
	gedis.flushall()

func bench_sorted_set_zrangebyscore(gedis: Gedis):
	gedis.flushall()
	for i in range(MEDIUM):
		gedis.zadd("zset", "member_%d" % i, i)
	var iterations = SMALL
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		gedis.zrangebyscore("zset", i, i + 10)
	var elapsed = Time.get_ticks_usec() - start
	print("sorted_set_zrangebyscore: %d range queries in %dms (set size %d)" % [iterations, elapsed / 1000, MEDIUM])
	gedis.flushall()

func bench_sorted_set_zrevrange(gedis: Gedis):
	gedis.flushall()
	for i in range(MEDIUM):
		gedis.zadd("zset", "member_%d" % i, i)
	var iterations = MEDIUM
	var start = Time.get_ticks_usec()
	for i in range(iterations):
		gedis.zrevrange("zset", 0, 9)
	var elapsed = Time.get_ticks_usec() - start
	print("sorted_set_zrevrange: %d top-10 queries in %dms (set size %d)" % [iterations, elapsed / 1000, MEDIUM])
	gedis.flushall()


# --- Core / _touch_type Benchmarks ---

func bench_touch_type_existing_key(gedis: Gedis):
	gedis.flushall()
	# Pre-populate keys
	for i in range(LARGE):
		gedis.set_value("key_%d" % i, i)
	# Benchmark overwrites (key already in correct bucket)
	var start = Time.get_ticks_usec()
	for i in range(LARGE):
		gedis.set_value("key_%d" % i, i + 1)
	var elapsed = Time.get_ticks_usec() - start
	print("touch_type_existing_key: %d overwrites in %dms" % [LARGE, elapsed / 1000])
	gedis.flushall()

func bench_touch_type_new_key(gedis: Gedis):
	gedis.flushall()
	var start = Time.get_ticks_usec()
	for i in range(LARGE):
		gedis.set_value("key_%d" % i, i)
	var elapsed = Time.get_ticks_usec() - start
	print("touch_type_new_key: %d new inserts in %dms" % [LARGE, elapsed / 1000])
	gedis.flushall()


# --- key_exists / _get_all_keys Benchmarks ---

func bench_key_exists(gedis: Gedis):
	gedis.flushall()
	# Spread keys across multiple types
	for i in range(MEDIUM):
		gedis.set_value("str_%d" % i, i)
	for i in range(MEDIUM):
		gedis.hset("hash_%d" % i, "f", i)
	for i in range(MEDIUM):
		gedis.sadd("set_%d" % i, "m")
	var start = Time.get_ticks_usec()
	for i in range(MEDIUM):
		gedis.key_exists("str_%d" % i)
		gedis.key_exists("hash_%d" % i)
		gedis.key_exists("set_%d" % i)
	var elapsed = Time.get_ticks_usec() - start
	print("key_exists: %d lookups in %dms (across 3 types)" % [MEDIUM * 3, elapsed / 1000])
	gedis.flushall()

func bench_get_all_keys(gedis: Gedis):
	gedis.flushall()
	for i in range(MEDIUM):
		gedis.set_value("str_%d" % i, i)
	for i in range(SMALL):
		gedis.hset("hash_%d" % i, "f", i)
	for i in range(SMALL):
		gedis.sadd("set_%d" % i, "m")
	var total_keys = MEDIUM + SMALL * 2
	var iterations = SMALL
	var start = Time.get_ticks_usec()
	for _i in range(iterations):
		gedis.keys("*")
	var elapsed = Time.get_ticks_usec() - start
	print("keys('*'): %d scans in %dms (total keys %d)" % [iterations, elapsed / 1000, total_keys])
	gedis.flushall()

func bench_dbsize(gedis: Gedis):
	gedis.flushall()
	var num_keys = MEDIUM
	for i in range(num_keys):
		gedis.set_value("key_%d" % i, i)
	var iterations = MEDIUM
	var start = Time.get_ticks_usec()
	for _i in range(iterations):
		gedis.dbsize()
	var elapsed = Time.get_ticks_usec() - start
	print("dbsize: %d calls in %dms (total keys %d)" % [iterations, elapsed / 1000, num_keys])
	gedis.flushall()


# --- Set Intersection Benchmark ---

func bench_sinter(gedis: Gedis):
	gedis.flushall()
	# Create two sets with overlap
	for i in range(MEDIUM):
		gedis.sadd("set_a", "member_%d" % i)
	for i in range(MEDIUM / 2, MEDIUM + MEDIUM / 2):
		gedis.sadd("set_b", "member_%d" % i)
	var start = Time.get_ticks_usec()
	for _i in range(SMALL):
		gedis.sinter(["set_a", "set_b"])
	var elapsed = Time.get_ticks_usec() - start
	print("sinter: %d intersections in %dms (set sizes %d, %d)" % [SMALL, elapsed / 1000, MEDIUM, MEDIUM])
	gedis.flushall()


# --- List Operation Benchmarks ---

func bench_list_lpop(gedis: Gedis):
	gedis.flushall()
	for i in range(LARGE):
		gedis.rpush("list", i)
	var start = Time.get_ticks_usec()
	for _i in range(MEDIUM):
		gedis.lpop("list")
	var elapsed = Time.get_ticks_usec() - start
	print("list_lpop: %d pops in %dms (initial size %d)" % [MEDIUM, elapsed / 1000, LARGE])
	gedis.flushall()

func bench_list_rpop(gedis: Gedis):
	gedis.flushall()
	for i in range(LARGE):
		gedis.rpush("list", i)
	var start = Time.get_ticks_usec()
	for _i in range(MEDIUM):
		gedis.rpop("list")
	var elapsed = Time.get_ticks_usec() - start
	print("list_rpop: %d pops in %dms (initial size %d)" % [MEDIUM, elapsed / 1000, LARGE])
	gedis.flushall()

func bench_list_lset(gedis: Gedis):
	gedis.flushall()
	for i in range(LARGE):
		gedis.rpush("list", i)
	var start = Time.get_ticks_usec()
	for i in range(MEDIUM):
		gedis.lset("list", i, i + 1)
	var elapsed = Time.get_ticks_usec() - start
	print("list_lset: %d updates in %dms (list size %d)" % [MEDIUM, elapsed / 1000, LARGE])
	gedis.flushall()


# --- Pub/Sub Benchmarks ---

func bench_publish_with_pattern_subscribers(gedis: Gedis):
	gedis.flushall()
	# Register pattern subscribers
	var dummy = Node.new()
	get_root().add_child(dummy)
	for i in range(SMALL):
		gedis.psubscribe("gedis:keyspace:pattern_%d:*" % i, dummy)
	# Benchmark publishes that must check all patterns
	var start = Time.get_ticks_usec()
	for i in range(MEDIUM):
		gedis._pubsub.publish("gedis:keyspace:key_%d" % i, "set")
	var elapsed = Time.get_ticks_usec() - start
	print("publish_with_patterns: %d publishes in %dms (%d patterns)" % [MEDIUM, elapsed / 1000, SMALL])
	dummy.queue_free()
	gedis.flushall()

func bench_publish_with_direct_subscribers(gedis: Gedis):
	gedis.flushall()
	var dummy = Node.new()
	get_root().add_child(dummy)
	# Subscribe to many channels
	for i in range(SMALL):
		gedis.subscribe("channel_%d" % i, dummy)
	var start = Time.get_ticks_usec()
	for i in range(MEDIUM):
		gedis._pubsub.publish("channel_%d" % (i % SMALL), "msg")
	var elapsed = Time.get_ticks_usec() - start
	print("publish_with_direct: %d publishes in %dms (%d channels)" % [MEDIUM, elapsed / 1000, SMALL])
	dummy.queue_free()
	gedis.flushall()


# --- _delete_all_types_for_key Benchmark ---

func bench_delete_all_types(gedis: Gedis):
	gedis.flushall()
	for i in range(LARGE):
		gedis.set_value("key_%d" % i, i)
	var start = Time.get_ticks_usec()
	for i in range(LARGE):
		gedis.del("key_%d" % i)
	var elapsed = Time.get_ticks_usec() - start
	print("delete_all_types: %d deletions in %dms" % [LARGE, elapsed / 1000])
	gedis.flushall()
