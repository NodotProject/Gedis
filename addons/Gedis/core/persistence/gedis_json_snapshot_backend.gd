class_name GedisJSONSnapshotBackend extends GedisPersistenceBackend

func save(data: Dictionary, options: Dictionary) -> int:
	var path: String = options.get("path", "")
	if path.is_empty():
		push_error("JSON snapshot backend requires a 'path' in options.")
		return FAILED

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: %s" % path)
		return FAILED

	# Serialize variants to strings
	var serializable_data = {}
	for bucket_name in data:
		var bucket = data[bucket_name]
		var serializable_bucket = {}
		for key in bucket:
			var value = bucket[key]
			if typeof(value) in [TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]:
				serializable_bucket[key] = var_to_str(value)
			else:
				serializable_bucket[key] = value
		serializable_data[bucket_name] = serializable_bucket
	
	var json_string = JSON.stringify(serializable_data, "\t")
	file.store_string(json_string)
	file.close()
	
	return OK


func load(options: Dictionary) -> Dictionary:
	var path: String = options.get("path", "")
	if path.is_empty():
		push_error("JSON snapshot backend requires a 'path' in options.")
		return {}

	if not FileAccess.file_exists(path):
		return {} # Return empty dict if file doesn't exist, not an error

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file for reading: %s" % path)
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse JSON from file: %s" % path)
		return {}

	var loaded_data: Dictionary = json.get_data()

	# Deserialize variants from strings
	for bucket_name in loaded_data:
		var bucket = loaded_data[bucket_name]
		if typeof(bucket) == TYPE_DICTIONARY:
			for key in bucket:
				var value = bucket[key]
				if typeof(value) == TYPE_STRING and value.begins_with("@"):
					bucket[key] = str_to_var(value)
		elif typeof(bucket) == TYPE_STRING and bucket.begins_with("@"):
			loaded_data[bucket_name] = str_to_var(bucket)
	
	return loaded_data

func serialize(data: Dictionary) -> String:
	var serializable_data = {}
	for bucket_name in data:
		var bucket = data[bucket_name]
		var serializable_bucket = {}
		for key in bucket:
			var value = bucket[key]
			if typeof(value) in [TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]:
				serializable_bucket[key] = var_to_str(value)
			else:
				serializable_bucket[key] = value
		serializable_data[bucket_name] = serializable_bucket
	
	return JSON.stringify(serializable_data, "\t")

func deserialize(data: String) -> Dictionary:
	var json = JSON.new()
	var error = json.parse(data)
	if error != OK:
		push_error("Failed to parse JSON from string")
		return {}

	var loaded_data: Dictionary = json.get_data()

	# Deserialize variants from strings
	for bucket_name in loaded_data:
		var bucket = loaded_data[bucket_name]
		if typeof(bucket) == TYPE_DICTIONARY:
			for key in bucket:
				var value = bucket[key]
				if typeof(value) == TYPE_STRING and value.begins_with("@"):
					bucket[key] = str_to_var(value)
		elif typeof(bucket) == TYPE_STRING and bucket.begins_with("@"):
			loaded_data[bucket_name] = str_to_var(bucket)
	
	return loaded_data