# Gedis

<img src="addons/gedis/icon.png" alt="Gedis logo" width="128" height="128" />

Redis-like in-memory key-value store for Godot 4.5, implemented in GDScript.

Gedis is a lightweight plugin that provides a convenient, Redis-inspired API for storing and retrieving data at runtime. It ships as an autoloaded singleton so you can access it anywhere: `Gedis.set("score", 10)`.

## Features
- Simple key-value API: set, get, del, exists, incr, decr
- Hashes (maps): hset, hget, hgetall, hdel
- Lists: lpush, rpush, lpop, rpop, llen
- Sets: sadd, srem, smembers, sismember
- Expiration (TTL): expire, ttl, persist
- In-memory only; no external dependencies

## Installation
1. Copy the `addons/gedis` folder into your Godot project, or add this repository as a submodule.
2. In Godot, go to Project -> Project Settings -> Plugins and enable the "Gedis" plugin.
3. The plugin will register an autoloaded singleton called `Gedis`.

## Usage
```gdscript
# Basic KV
Gedis.set("score", 10)
var current = Gedis.get("score") # 10
Gedis.incr("score")               # 11
Gedis.decr("score", 2)            # 9

# Expiration
Gedis.expire("score", 5) # expire in 5 seconds
var t = Gedis.ttl("score") # seconds remaining, -1 if no expiry, -2 if missing

# Hashes
Gedis.hset("player:1", "name", "Alex")
Gedis.hset("player:1", "hp", 100)
var name = Gedis.hget("player:1", "name")          # "Alex"
var fields = Gedis.hgetall("player:1")              # {"name": "Alex", "hp": 100}

# Lists
Gedis.lpush("recent_events", "spawn")
Gedis.rpush("recent_events", "move")
var first = Gedis.lpop("recent_events") # "spawn"

# Sets
Gedis.sadd("unlocked_items", "sword")
Gedis.sadd("unlocked_items", "shield")
var has_sword = Gedis.sismember("unlocked_items", "sword") # true
var items = Gedis.smembers("unlocked_items")

# Keys pattern
var k = Gedis.keys("player:*")
```

## Notes
- This is a pure in-memory store. Data is not persisted across runs.
- Key namespaces (simple convention) can help organize data, e.g., `player:1:name` or `player:1` hash.
- TTL is maintained lazily on access and also purged every frame; extremely large key counts may warrant batching.

## Compatibility
- Godot 4.5

## License
MIT — see LICENSE for details.
