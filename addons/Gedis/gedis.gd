class_name Gedis extends Node

# Component instances
var _core: GedisCore
var _expiry: GedisExpiry
var _strings: GedisStrings
var _hashes: GedisHashes
var _lists: GedisLists
var _sets: GedisSets
var _sorted_sets: GedisSortedSets = preload("res://addons/Gedis/core/gedis_sorted_sets.gd").new()
var _pubsub: GedisPubSub
var _debugger_component: GedisDebugger
var _utils: GedisUtils

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
	_expiry = GedisExpiry.new(self)
	_strings = GedisStrings.new(self)
	_hashes = GedisHashes.new(self)
	_lists = GedisLists.new(self)
	_sets = GedisSets.new(self)
	_pubsub = GedisPubSub.new(self)
	_debugger_component = GedisDebugger.new(self)
	
	GedisDebugger._ensure_debugger_is_registered()

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

# --- Public API ---

# Strings
func set_value(key: StringName, value: Variant) -> void:
	_strings.set_value(key, value)

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _strings.get_value(key, default_value)

func del(keys) -> int:
	return _strings.del(keys)

func exists(keys) -> Variant:
	return _strings.exists(keys)

func key_exists(key: String) -> bool:
	return _strings.key_exists(key)

func incr(key: String, amount: int = 1) -> int:
	return _strings.incr(key, amount)

func decr(key: String, amount: int = 1) -> int:
	return _strings.decr(key, amount)

func keys(pattern: String = "*") -> Array:
	return _strings.keys(pattern)

func mset(dict: Dictionary) -> void:
	_strings.mset(dict)

func mget(keys: Array) -> Array:
	return _strings.mget(keys)

# Hashes
func hset(key: String, field: String, value) -> int:
	return _hashes.hset(key, field, value)

func hget(key: String, field: String, default_value: Variant = null):
	return _hashes.hget(key, field, default_value)

func hdel(key: String, fields) -> int:
	return _hashes.hdel(key, fields)

func hgetall(key: String) -> Dictionary:
	return _hashes.hgetall(key)

func hexists(key: String, field: String) -> bool:
	return _hashes.hexists(key, field)

func hkeys(key: String) -> Array:
	return _hashes.hkeys(key)

func hvals(key: String) -> Array:
	return _hashes.hvals(key)

func hlen(key: String) -> int:
	return _hashes.hlen(key)

# Lists
func lpush(key: String, value) -> int:
	return _lists.lpush(key, value)

func rpush(key: String, value) -> int:
	return _lists.rpush(key, value)

func lpop(key: String):
	return _lists.lpop(key)

func rpop(key: String):
	return _lists.rpop(key)

func llen(key: String) -> int:
	return _lists.llen(key)

func lget(key: String) -> Array:
	return _lists.lget(key)

func lrange(key: String, start: int, stop: int) -> Array:
	return _lists.lrange(key, start, stop)

func lindex(key: String, index: int):
	return _lists.lindex(key, index)

func lset(key: String, index: int, value) -> bool:
	return _lists.lset(key, index, value)

func lrem(key: String, count: int, value) -> int:
	return _lists.lrem(key, count, value)

# Sets
func sadd(key: String, member) -> int:
	return _sets.sadd(key, member)

func srem(key: String, member) -> int:
	return _sets.srem(key, member)

func smembers(key: String) -> Array:
	return _sets.smembers(key)

func sismember(key: String, member) -> bool:
	return _sets.sismember(key, member)

func scard(key: String) -> int:
	return _sets.scard(key)

func spop(key: String):
	return _sets.spop(key)

func smove(source: String, destination: String, member) -> bool:
	return _sets.smove(source, destination, member)

# Sorted Sets
func zadd(key: String, member: String, score: int):
	return _sorted_sets.add(member, score)

func zrem(key: String, member: String):
	return _sorted_sets.remove(member)

func zrangebyscore(key: String, min: int, max: int):
	return _sorted_sets.range_by_score(min, max)

func zpopready(key: String, now: int):
	return _sorted_sets.pop_ready(now)

# Pub/Sub
func publish(channel: String, message) -> void:
	_pubsub.publish(channel, message)

func subscribe(channel: String, subscriber: Object) -> void:
	_pubsub.subscribe(channel, subscriber)

func unsubscribe(channel: String, subscriber: Object) -> void:
	_pubsub.unsubscribe(channel, subscriber)

func psubscribe(pattern: String, subscriber: Object) -> void:
	_pubsub.psubscribe(pattern, subscriber)

func punsubscribe(pattern: String, subscriber: Object) -> void:
	_pubsub.punsubscribe(pattern, subscriber)

# Expiry
func expire(key: String, seconds: int) -> bool:
	return _expiry.expire(key, seconds)

func ttl(key: String) -> int:
	return _expiry.ttl(key)

func persist(key: String) -> bool:
	return _expiry.persist(key)

# Admin
func flushall() -> void:
	_core.flushall()

# Debugger
func type(key: String) -> String:
	return _debugger_component.type(key)

func dump(key: String) -> Dictionary:
	return _debugger_component.dump(key)

func snapshot(pattern: String = "*") -> Dictionary:
	return _debugger_component.snapshot(pattern)

# Instance helpers
func set_instance_name(name: String) -> void:
	_instance_name = name

func get_instance_name() -> String:
	return _instance_name

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
