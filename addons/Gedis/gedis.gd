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
	_core = GedisCore.new(self)
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

func _exit_tree() -> void:
	# unregister instance
	for i in range(_instances.size()):
		if _instances[i] == self:
			_instances.remove_at(i)
			break

func _process(delta: float) -> void:
	_time_source.tick(delta)
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
func incrby(key: String, amount: int = 1) -> int:
	return _strings.incrby(key, amount)

## Decrements the integer value of a key by a given amount.
func decrby(key: String, amount: int = 1) -> int:
	return _strings.decrby(key, amount)

## Gets all keys matching a pattern.
func keys(pattern: String = "*") -> Array:
	return _strings.keys(pattern)

## Sets multiple keys to multiple values.
func mset(dict: Dictionary) -> void:
	_strings.mset(dict)

## Gets the values of all specified keys.
func mget(keys: Array) -> Array:
	return _strings.mget(keys)

## Appends a value to a key.
func append(key: String, value: String) -> int:
	return _strings.append(key, value)

## Atomically sets a key to a value and returns the old value.
func getset(key: String, value: Variant) -> Variant:
	return _strings.getset(key, value)

## Gets the length of the string value of a key.
func strlen(key: String) -> int:
	return _strings.strlen(key)

## Sets a key to a value, only if the key does not exist.
func setnx(key: String, value: Variant) -> int:
	return _strings.setnx(key, value)

## Renames a key to newkey, only if newkey does not exist.
func rename(key: String, newkey: String) -> int:
	return _core.rename(key, newkey)

## Moves a key to another key.
func move(key: String, newkey: String) -> int:
	return _core.move(key, newkey)

## Returns a random key from the database.
func randomkey() -> String:
	var all_keys = _core._get_all_keys().keys()
	if all_keys.is_empty():
		return ""
	return all_keys.pick_random()

## Returns the number of keys in the database.
func dbsize() -> int:
	return _core._get_all_keys().size()

## Adds the keyspace prefix to a key
func ks(key: String) -> String:
	return _core.ks(key)
	
## Removes the keyspace prefix of a key
func rks(key: String) -> String:
	return _core.rks(key)

# Hashes
## Sets the string value of a hash field.
func hset(key: String, field: String, value) -> int:
	return _hashes.hset(key, field, value)

## Gets the value of a hash field.
func hget(key: String, field: String, default_value: Variant = null):
	return _hashes.hget(key, field, default_value)

## Gets the values of all the given hash fields.
func hmget(key: String, fields: Array) -> Array:
	return _hashes.hmget(key, fields)

## Sets multiple hash fields to multiple values.
func hmset(key: String, field_value_pairs: Dictionary) -> void:
	_hashes.hmset(key, field_value_pairs)

## Increments the integer value of a hash field by the given amount.
func hincrby(key: String, field: String, amount: int) -> Variant:
	return _hashes.hincrby(key, field, amount)

## Increments the float value of a hash field by the given amount.
func hincrbyfloat(key: String, field: String, amount: float) -> Variant:
	return _hashes.hincrbyfloat(key, field, amount)

## Deletes one or more hash fields.
func hdel(key: String, fields) -> int:
	return _hashes.hdel(key, fields)

## Gets all the fields and values in a hash.
func hgetall(key: String) -> Dictionary:
	return _hashes.hgetall(key)

## Checks if a hash field exists.
func hexists(key: String, field = null) -> bool:
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

## Trims a list to the specified range of indices.
func ltrim(key: String, start: int, stop: int) -> bool:
	return _lists.ltrim(key, start, stop)

## Inserts a value into a list before or after a pivot value.
func linsert(key: String, position: String, pivot, value) -> int:
	return _lists.linsert(key, position, pivot, value)

## Atomically returns and removes the first/last element of the list stored at source and pushes the element at the first/last element of the list stored at destination.
func lmove(source: String, destination: String, from: String, to: String):
	return _lists.lmove(source, destination, from, to)
	
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

## Returns the union of the sets stored at the given keys.
func sunion(keys: Array) -> Array:
	return _sets.sunion(keys)

## Returns the intersection of the sets stored at the given keys.
func sinter(keys: Array) -> Array:
	return _sets.sinter(keys)

## Returns the difference of the sets stored at the given keys.
func sdiff(keys: Array) -> Array:
	return _sets.sdiff(keys)

## Stores the union of the sets at keys in the destination key.
func sunionstore(destination: String, keys: Array) -> int:
	return _sets.sunionstore(destination, keys)

## Stores the intersection of the sets at keys in the destination key.
func sinterstore(destination: String, keys: Array) -> int:
	return _sets.sinterstore(destination, keys)

## Stores the difference of the sets at keys in the destination key.
func sdiffstore(destination: String, keys: Array) -> int:
	return _sets.sdiffstore(destination, keys)

## Returns one or more random members from the set at key.
func srandmember(key: String, count: int = 1) -> Variant:
	return _sets.srandmember(key, count)

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

## Returns the score of member in the sorted set at key.
func zscore(key: String, member: String) -> Variant:
	return _sorted_sets.zscore(key, member)

## Returns the rank of member in the sorted set at key.
func zrank(key: String, member: String) -> Variant:
	return _sorted_sets.zrank(key, member)

## Returns the rank of member in the sorted set at key, with scores ordered from high to low.
func zrevrank(key: String, member: String) -> Variant:
	return _sorted_sets.zrevrank(key, member)

## Returns the number of elements in the sorted set at key with a score between min and max.
func zcount(key: String, min_score, max_score) -> int:
	return _sorted_sets.zcount(key, min_score, max_score)

## Increments the score of member in the sorted set at key by increment.
func zincrby(key: String, increment, member: String) -> Variant:
	return _sorted_sets.zincrby(key, increment, member)

## Returns a range of members in a sorted set, by score.
func zrangebyscore(key: String, min_score, max_score, withscores: bool = false) -> Array:
	return _sorted_sets.zrangebyscore(key, min_score, max_score, withscores)

## Returns a range of members in a sorted set, by score, in reverse order.
func zrevrangebyscore(key: String, min_score, max_score, withscores: bool = false) -> Array:
	return _sorted_sets.zrevrangebyscore(key, min_score, max_score, withscores)

## Computes the union of sorted sets and stores the result in a new key.
func zunionstore(destination: String, keys: Array, aggregate: String = "SUM") -> int:
	return _sorted_sets.zunionstore(destination, keys, aggregate)

## Computes the intersection of sorted sets and stores the result in a new key.
func zinterstore(destination: String, keys: Array, aggregate: String = "SUM") -> int:
	return _sorted_sets.zinterstore(destination, keys, aggregate)

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
	
	var data = _core.dump_all(dump_options)
	
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

	_core.restore_all(data)
	return OK

## Dumps the entire dataset to a variable.
func dump_all(options: Dictionary = {}) -> Dictionary:
	return _core.dump_all(options)

## Restores the entire dataset from a variable.
func restore_all(data: Dictionary) -> void:
	_core.restore_all(data)

## Restores a key from a serialized value.
func restore(key: String, data: String, backend: String = "") -> int:
	var persistence_backend: GedisPersistenceBackend
	if backend.is_empty():
		if _default_persistence_backend.is_empty():
			register_persistence_backend("json", GedisJSONSnapshotBackend.new())
			set_default_persistence_backend("json")
		persistence_backend = _persistence_backends[_default_persistence_backend]
	elif _persistence_backends.has(backend):
		persistence_backend = _persistence_backends[backend]
	else:
		return FAILED

	var deserialized_data = persistence_backend.deserialize(data)
	if deserialized_data.is_empty():
		return FAILED
	
	_core.restore_key(key, deserialized_data)
	return OK

# Debugger
## Returns the type of the value stored at a key.
func type(key: String) -> String:
	return _debugger_component.type(key)

## Returns a dictionary representation of the value stored at a key.
func dump_key(key: String) -> Dictionary:
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
