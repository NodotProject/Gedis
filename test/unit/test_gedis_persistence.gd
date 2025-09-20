extends GutTest

var gedis: Gedis

func before_each():
	gedis = Gedis.new()
	add_child(gedis)
	gedis.flushall()
	
	var backend = GedisJSONSnapshotBackend.new()
	gedis.register_persistence_backend("json", backend)
	gedis.set_default_persistence_backend("json")

func after_each():
	gedis.queue_free()

func test_dump_and_restore():
	gedis.set_value("string_key", "hello")
	gedis.hset("hash_key", "field1", "value1")
	gedis.lpush("list_key", "item1")
	gedis.sadd("set_key", "member1")
	
	var dump = gedis._core.dump_all()
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	new_gedis._core.restore_all(dump)
	
	assert_eq(new_gedis.get_value("string_key"), "hello", "String should be restored")
	assert_eq(new_gedis.hget("hash_key", "field1"), "value1", "Hash should be restored")
	assert_eq(new_gedis.lpop("list_key"), "item1", "List should be restored")
	assert_true(new_gedis.sismember("set_key", "member1"), "Set should be restored")
	new_gedis.queue_free()

func test_dump_namespace_filtering():
	gedis.set_value("user:1", "Alice")
	gedis.set_value("user:2", "Bob")
	gedis.set_value("session:1", "active")
	
	var user_dump = gedis._core.dump_all({"include": ["user:"]})
	assert_true(user_dump.store.has("user:1"), "Include should keep user:1")
	assert_true(user_dump.store.has("user:2"), "Include should keep user:2")
	assert_false(user_dump.store.has("session:1"), "Include should remove session:1")
	
	var no_session_dump = gedis._core.dump_all({"exclude": ["session:"]})
	assert_true(no_session_dump.store.has("user:1"), "Exclude should keep user:1")
	assert_true(no_session_dump.store.has("user:2"), "Exclude should keep user:2")
	assert_false(no_session_dump.store.has("session:1"), "Exclude should remove session:1")

func test_ttl_preservation():
	gedis.set_value("mykey", "some_value")
	gedis.expire("mykey", 10) # Expires in 10 seconds
	
	var dump = gedis._core.dump_all()
	var expiry_time = dump.expiry.mykey
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	new_gedis._core.restore_all(dump)
	
	assert_true(new_gedis._core._expiry.has("mykey"), "Expiry key should be restored")
	assert_eq(new_gedis._core._expiry.mykey, expiry_time, "Expiry time should be identical")
	new_gedis.queue_free()

func test_expired_key_on_restore():
	gedis.set_value("mykey", "some_value")
	gedis.expire("mykey", -10) # Expired 10 seconds ago
	
	var dump = gedis._core.dump_all()
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	new_gedis._core.restore_all(dump)
	
	assert_false(new_gedis.key_exists("mykey"), "Expired key should not be restored")
	new_gedis.queue_free()

func test_save_and_load_json():
	var save_path = "user://gedis_test_save.json"
	gedis.set_value("string_key", "hello world")
	gedis.hset("hash_key", "field", 123)
	
	var result = gedis.save(save_path)
	assert_eq(result, OK, "Save should return OK")
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	
	var backend = GedisJSONSnapshotBackend.new()
	new_gedis.register_persistence_backend("json", backend)
	new_gedis.set_default_persistence_backend("json")
	
	result = new_gedis.load(save_path)
	assert_eq(result, OK, "Load should return OK")
	
	assert_eq(new_gedis.get_value("string_key"), "hello world", "String should be loaded from file")
	assert_eq(new_gedis.hget("hash_key", "field"), 123, "Hash should be loaded from file")
	
	# Clean up the file
	var dir_access = DirAccess.open("user://")
	dir_access.remove(save_path)
	new_gedis.queue_free()

func test_save_with_invalid_path():
	var invalid_path = "res://non_existent_dir/test.json"
	var result = gedis.save(invalid_path)
	assert_eq(result, FAILED, "Save should fail with an invalid path")

func test_load_with_invalid_path():
	var invalid_path = "res://non_existent_dir/test.json"
	var result = gedis.load(invalid_path)
	assert_eq(result, FAILED, "Load should fail for a non-existent file")
	assert_eq(gedis.keys().size(), 0, "No data should be loaded from a non-existent file")

func test_load_with_corrupted_json():
	var save_path = "user://corrupted.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{'invalid_json': ")
	file.close()
	
	var result = gedis.load(save_path)
	assert_eq(result, FAILED, "Load should fail for corrupted JSON")
	assert_eq(gedis.keys().size(), 0, "No data should be loaded from a corrupted file")
	
	var dir_access = DirAccess.open("user://")
	dir_access.remove(save_path)

func test_save_and_load_with_exclude_filter():
	var save_path = "user://gedis_test_exclude.json"
	gedis.set_value("user:1", "Alice")
	gedis.set_value("session:1", "active")
	
	var result = gedis.save(save_path, {"exclude": ["session:"]})
	assert_eq(result, OK, "Save with exclude filter should succeed")
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	var backend = GedisJSONSnapshotBackend.new()
	new_gedis.register_persistence_backend("json", backend)
	new_gedis.set_default_persistence_backend("json")
	
	result = new_gedis.load(save_path)
	assert_eq(result, OK, "Load should succeed")
	
	assert_true(new_gedis.key_exists("user:1"), "Included key should be loaded")
	assert_false(new_gedis.key_exists("session:1"), "Excluded key should not be loaded")
	
	var dir_access = DirAccess.open("user://")
	dir_access.remove(save_path)
	new_gedis.queue_free()

func test_save_and_load_with_include_filter():
	var save_path = "user://gedis_test_include.json"
	gedis.set_value("user:1", "Alice")
	gedis.set_value("session:1", "active")
	
	var result = gedis.save(save_path, {"include": ["user:"]})
	assert_eq(result, OK, "Save with include filter should succeed")
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	var backend = GedisJSONSnapshotBackend.new()
	new_gedis.register_persistence_backend("json", backend)
	new_gedis.set_default_persistence_backend("json")
	
	result = new_gedis.load(save_path)
	assert_eq(result, OK, "Load should succeed")
	
	assert_true(new_gedis.key_exists("user:1"), "Included key should be loaded")
	assert_false(new_gedis.key_exists("session:1"), "Excluded key should not be loaded")
	
	var dir_access = DirAccess.open("user://")
	dir_access.remove(save_path)
	new_gedis.queue_free()

func test_save_and_load_complex_data_structures():
	var save_path = "user://gedis_test_complex.json"
	var complex_data = {
		"nested_dict": {
			"a": 1,
			"b": [1, 2, 3]
		},
		"nested_array": [
			{"id": 1, "value": "one"},
			{"id": 2, "value": "two"}
		]
	}
	gedis.set_value("complex_key", complex_data)
	
	var result = gedis.save(save_path)
	assert_eq(result, OK, "Save with complex data should succeed")
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	var backend = GedisJSONSnapshotBackend.new()
	new_gedis.register_persistence_backend("json", backend)
	new_gedis.set_default_persistence_backend("json")
	
	result = new_gedis.load(save_path)
	assert_eq(result, OK, "Load with complex data should succeed")
	
	var loaded_data = new_gedis.get_value("complex_key")
	assert_eq(loaded_data["nested_dict"]["a"], 1, "Nested dictionary value should be correct")
	assert_eq(loaded_data["nested_array"][1]["value"], "two", "Nested array value should be correct")
	
	var dir_access = DirAccess.open("user://")
	dir_access.remove(save_path)
	new_gedis.queue_free()

func test_performance_with_large_dataset():
	var save_path = "user://gedis_perf_test.json"
	var num_keys = 10000
	
	for i in range(num_keys):
		gedis.set_value("key:" + str(i), "value:" + str(i))
		
	var start_time = Time.get_ticks_msec()
	var result = gedis.save(save_path)
	var save_time = Time.get_ticks_msec() - start_time
	
	assert_eq(result, OK, "Performance save should succeed")
	print("Save time for %d keys: %d ms" % [num_keys, save_time])
	
	var new_gedis = Gedis.new()
	add_child(new_gedis)
	var backend = GedisJSONSnapshotBackend.new()
	new_gedis.register_persistence_backend("json", backend)
	new_gedis.set_default_persistence_backend("json")
	
	start_time = Time.get_ticks_msec()
	result = new_gedis.load(save_path)
	var load_time = Time.get_ticks_msec() - start_time
	
	assert_eq(result, OK, "Performance load should succeed")
	assert_eq(new_gedis.keys().size(), num_keys, "All keys should be loaded")
	print("Load time for %d keys: %d ms" % [num_keys, load_time])
	
	var dir_access = DirAccess.open("user://")
	dir_access.remove(save_path)
	new_gedis.queue_free()
	
func test_restore_top_level():
	gedis.set_value("key1", "value1")
	var dump_data = gedis.dump_key("key1")
	gedis.del("key1")
	assert_false(gedis.key_exists("key1"))
	assert_eq(gedis.restore("key1", JSON.stringify(dump_data)), OK)
	assert_eq(gedis.get_value("key1"), "value1")

func test_restore_key():
	gedis.set_value("key1", "value1")
	var dump_data = gedis.dump_key("key1")
	gedis.del("key1")
	assert_false(gedis.key_exists("key1"))
	gedis._core.restore_key("key1", dump_data)
	assert_eq(gedis.get_value("key1"), "value1")

func test_json_backend_serialize_deserialize():
	var backend = GedisJSONSnapshotBackend.new()
	var data = {
		"store": {
			"key1": {"type": "string", "value": "hello"},
			"key2": {"type": "list", "value": ["a", "b"]},
		},
		"expiry": {
			"key1": 12345
		}
	}
	var serialized_data = backend.serialize(data)
	var deserialized_data = backend.deserialize(serialized_data)
	assert_eq(deserialized_data.store.key1.value, "hello")
	assert_eq(deserialized_data.store.key2.value, ["a", "b"])
	assert_eq(deserialized_data.expiry.key1, 12345)