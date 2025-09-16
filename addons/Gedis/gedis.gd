class_name Gedis extends Node

# Component instances
var _core: GedisCore
var _expiry: GedisExpiry
var _time_source: GedisTimeSource
var _strings: GedisStrings
var _hashes: GedisHashes
var _lists: GedisLists
var _sets: GedisSets
var _sorted_sets: GedisSortedSets
var _pubsub: GedisPubSub
var _debugger_component: GedisDebugger
var _utils: GedisUtils
var _persistence_backends: Dictionary = {}
var _default_persistence_backend: String = ""

# Instance registry
static var _instances: Array = []
static var _next_instance_id: int = 0
var _instance_id: int = -1
var _instance_name: String = ""
static var _debugger_registered = false

func _init() -> void:
	# assign id and register
	_instance_id = _next_instance_id
	_next_instance_id += 1
	_instance_name = "Gedis_%d" % _instance_id
	_instances.append(self)

	# Instantiate components
	_core = GedisCore.new()
	_utils = GedisUtils.new()
	_time_source = GedisUnixTimeSource.new()
	_expiry = GedisExpiry.new(self)
	_strings = GedisStrings.new(self)
	_hashes = GedisHashes.new(self)
	_lists = GedisLists.new(self)
	_sets = GedisSets.new(self)
	_sorted_sets = GedisSortedSets.new(self)
	_pubsub = GedisPubSub.new(self)
	_debugger_component = GedisDebugger.new(self)

	_pubsub.pubsub_message.connect(_on_pubsub_message)
	_pubsub.psub_message.connect(_on_psub_message)
	
	GedisDebugger._ensure_debugger_is_registered()

func _on_pubsub_message(channel: String, message: Variant) -> void:
	pubsub_message.emit(channel, message)

func _on_psub_message(pattern: String, channel: String, message: Variant) -> void:
	psub_message.emit(pattern, channel, message)

func _ready() -> void:
	set_process(true)

func _exit_tree() -> void:
	# unregister instance
	for i in range(_instances.size()):
		if _instances[i] == self:
			_instances.remove_at(i)
			break

func _process(_delta: float) -> void:
	_expiry._purge_expired()

# --- Time Source ---
func set_time_source(p_time_source: GedisTimeSource) -> void:
	_time_source = p_time_source

func get_time_source() -> GedisTimeSource:
	return _time_source

# --- Public API ---

signal pubsub_message(channel, message)
signal psub_message(pattern, channel, message)

## Sets a value for a key
func set_value(key: StringName, value: Variant) -> void:
	_strings.set_value(key, value)

## Sets a key to a value with an expiration time in seconds.
func setex(key: StringName, seconds: int, value: Variant) -> void:
	set_value(key, value)
	expire(key, seconds)

## Gets the string value of a key.
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _strings.get_value(key, default_value)

## Deletes one or more keys.
func del(keys) -> int:
	return _strings.del(keys)

## Checks if one or more keys exist.
func exists(keys) -> Variant:
	return _strings.exists(keys)

## Checks if a key exists.
func key_exists(key: String) -> bool:
	return _strings.key_exists(key)

## Increments the integer value of a key by a given amount.
func incr(key: String, amount: int = 1) -> int:
	return _strings.incr(key, amount)

## Decrements the integer value of a key by a given amount.
func decr(key: String, amount: int = 1) -> int:
	return _strings.decr(key, amount)

## Gets all keys matching a pattern.
func keys(pattern: String = "*") -> Array:
	return _strings.keys(pattern)

## Sets multiple keys to multiple values.
func mset(dict: Dictionary) -> void:
	_strings.mset(dict)

## Gets the values of all specified keys.
func mget(keys: Array) -> Array:
	return _strings.mget(keys)

# Hashes
## Sets the string value of a hash field.
func hset(key: String, field: String, value) -> int:
	return _hashes.hset(key, field, value)

## Gets the value of a hash field.
func hget(key: String, field: String, default_value: Variant = null):
	return _hashes.hget(key, field, default_value)

## Deletes one or more hash fields.
func hdel(key: String, fields) -> int:
	return _hashes.hdel(key, fields)

## Gets all the fields and values in a hash.
func hgetall(key: String) -> Dictionary:
	return _hashes.hgetall(key)

## Checks if a hash field exists.
func hexists(key: String, field: String) -> bool:
	return _hashes.hexists(key, field)

## Gets all the fields in a hash.
func hkeys(key: String) -> Array:
	return _hashes.hkeys(key)

## Gets all the values in a hash.
func hvals(key: String) -> Array:
	return _hashes.hvals(key)

## Gets the number of fields in a hash.
func hlen(key: String) -> int:
	return _hashes.hlen(key)

# Lists
## Prepends one or multiple values to a list.
func lpush(key: String, value) -> int:
	return _lists.lpush(key, value)

## Appends one or multiple values to a list.
func rpush(key: String, value) -> int:
	return _lists.rpush(key, value)

## Removes and gets the first element in a list.
func lpop(key: String):
	return _lists.lpop(key)

## Removes and gets the last element in a list.
func rpop(key: String):
	return _lists.rpop(key)

## Gets the length of a list.
func llen(key: String) -> int:
	return _lists.llen(key)

## Gets all elements from a list.
func lget(key: String) -> Array:
	return _lists.lget(key)

## Gets a range of elements from a list.
func lrange(key: String, start: int, stop: int) -> Array:
	return _lists.lrange(key, start, stop)

## Gets an element from a list by index.
func lindex(key: String, index: int):
	return _lists.lindex(key, index)

## Sets the value of an element in a list by index.
func lset(key: String, index: int, value) -> bool:
	return _lists.lset(key, index, value)

## Removes elements from a list.
func lrem(key: String, count: int, value) -> int:
	return _lists.lrem(key, count, value)

# Sets
## Adds one or more members to a set.
func sadd(key: String, member) -> int:
	return _sets.sadd(key, member)

## Removes one or more members from a set.
func srem(key: String, member) -> int:
	return _sets.srem(key, member)

## Gets all the members in a set.
func smembers(key: String) -> Array:
	return _sets.smembers(key)

## Checks if a member is in a set.
func sismember(key: String, member) -> bool:
	return _sets.sismember(key, member)

## Gets the number of members in a set.
func scard(key: String) -> int:
	return _sets.scard(key)

## Removes and returns a random member from a set.
func spop(key: String):
	return _sets.spop(key)

## Moves a member from one set to another.
func smove(source: String, destination: String, member) -> bool:
	return _sets.smove(source, destination, member)

# Sorted Sets
## Adds a member with a score to a sorted set.
func zadd(key: String, member: String, score: int):
	return _sorted_sets.add(key, member, score)

## Removes a member from a sorted set.
func zrem(key: String, member: String):
	return _sorted_sets.remove(key, member)

## Gets members from a sorted set within a score range.
func zrange(key: String, start, stop, withscores: bool = false):
	return _sorted_sets.zrange(key, start, stop, withscores)

## Gets members from a sorted set within a score range, in reverse order.
func zrevrange(key: String, start, stop, withscores: bool = false):
	return _sorted_sets.zrevrange(key, start, stop, withscores)

## Removes and returns members with scores up to a certain value.
func zpopready(key: String, now: int):
	return _sorted_sets.pop_ready(key, now)

# Pub/Sub
## Posts a message to a channel.
func publish(channel: String, message) -> void:
	_pubsub.publish(channel, message)

## Subscribes to a channel.
func subscribe(channel: String, subscriber: Object) -> void:
	_pubsub.subscribe(channel, subscriber)

## Unsubscribes from a channel.
func unsubscribe(channel: String, subscriber: Object) -> void:
	_pubsub.unsubscribe(channel, subscriber)

## Subscribes to channels matching a pattern.
func psubscribe(pattern: String, subscriber: Object) -> void:
	_pubsub.psubscribe(pattern, subscriber)

## Unsubscribes from channels matching a pattern.
func punsubscribe(pattern: String, subscriber: Object) -> void:
	_pubsub.punsubscribe(pattern, subscriber)

## Returns a list of all active channels.
func list_channels() -> Array:
	return _pubsub.list_channels()

## Returns a list of subscribers for a given channel.
func list_subscribers(channel: String) -> Array:
	return _pubsub.list_subscribers(channel)

## Returns a list of all active patterns.
func list_patterns() -> Array:
	return _pubsub.list_patterns()

## Returns a list of subscribers for a given pattern.
func list_pattern_subscribers(pattern: String) -> Array:
	return _pubsub.list_pattern_subscribers(pattern)

# Expiry
## Sets a key's time to live in seconds.
func expire(key: String, seconds: int) -> bool:
	return _expiry.expire(key, seconds)

## Gets the remaining time to live of a key.
func ttl(key: String) -> int:
	return _expiry.ttl(key)

## Removes the expiration from a key.
func persist(key: String) -> bool:
	return _expiry.persist(key)

# Admin
## Deletes all keys from the database.
func flushall() -> void:
	_core.flushall()

## Deletes all keys from the database. Alias for flushall.
func flushdb() -> void:
	_core.flushall()

func move(key: String, db_index: int) -> int:
	var destination_db: Gedis = null
	for inst_info in get_all_instances():
		if inst_info["id"] == db_index:
			destination_db = inst_info["object"]
			break

	if destination_db == null or destination_db == self:
		return 0

	if not _core.key_exists(key) or destination_db._core.key_exists(key):
		return 0

	var value
	if _core._store.has(key):
		value = _core._store[key]
		destination_db._core._store[key] = value
	elif _core._hashes.has(key):
		value = _core._hashes[key]
		destination_db._core._hashes[key] = value
	elif _core._lists.has(key):
		value = _core._lists[key]
		destination_db._core._lists[key] = value
	elif _core._sets.has(key):
		value = _core._sets[key]
		destination_db._core._sets[key] = value
	elif _core._sorted_sets.has(key):
		value = _core._sorted_sets[key]
		destination_db._core._sorted_sets[key] = value

	if _core._expiry.has(key):
		var expiry_time = _core._expiry[key]
		destination_db._core._expiry[key] = expiry_time

	_core._delete_all_types_for_key(key)
	return 1

# Persistence
## Registers a new persistence backend.
func register_persistence_backend(name: String, backend: GedisPersistenceBackend) -> void:
	_persistence_backends[name] = backend


## Sets the default persistence backend.
func set_default_persistence_backend(name: String) -> bool:
	if _persistence_backends.has(name):
		_default_persistence_backend = name
		return true
	return false


## Saves the current state to a file using the default persistence backend.
func save(path: String, options: Dictionary = {}) -> int:
	if _default_persistence_backend.is_empty():
		register_persistence_backend("json", GedisJSONSnapshotBackend.new())
		set_default_persistence_backend("json")

	var backend: GedisPersistenceBackend = _persistence_backends[_default_persistence_backend]
	var dump_options = options.duplicate()
	if dump_options.has("path"):
		dump_options.erase("path")
	
	var data = _core.dump(dump_options)
	
	var save_options = {"path": path}
	return backend.save(data, save_options)


## Loads the state from a file using the default persistence backend.
func load(path: String, options: Dictionary = {}) -> int:
	if _default_persistence_backend.is_empty():
		register_persistence_backend("json", GedisJSONSnapshotBackend.new())
		set_default_persistence_backend("json")

	var backend: GedisPersistenceBackend = _persistence_backends[_default_persistence_backend]
	var load_options = {"path": path}
	var data = backend.load(load_options)

	if data.is_empty():
		return FAILED

	_core.restore(data)
	return OK

# Debugger
## Returns the type of the value stored at a key.
func type(key: String) -> String:
	return _debugger_component.type(key)

## Returns a dictionary representation of the value stored at a key.
func dump(key: String) -> Dictionary:
	return _debugger_component.dump(key)

## Returns a snapshot of the database for keys matching a pattern.
func snapshot(pattern: String = "*") -> Dictionary:
	return _debugger_component.snapshot(pattern)

# Instance helpers
## Sets the name for this Gedis instance.
func set_instance_name(name: String) -> void:
	_instance_name = name

## Gets the name for this Gedis instance.
func get_instance_name() -> String:
	return _instance_name

## Gets all active Gedis instances.
static func get_all_instances() -> Array:
	var result: Array = []
	for inst in _instances:
		if is_instance_valid(inst):
			var info: Dictionary = {}
			info["id"] = inst._instance_id
			info["name"] = inst.name if inst.name else inst._instance_name
			info["object"] = inst
			result.append(info)
	return result

static func _on_debugger_message(message: String, data: Array) -> bool:
	return GedisDebugger._on_debugger_message(message, data)
