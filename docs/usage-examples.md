---
layout: page
title: Usage Examples
permalink: usage-examples
---

## Table of Contents

- [Strings](#strings)
- [Hashes](#hashes)
- [Lists](#lists)
- [Sets](#sets)
- [Sorted Sets](#sorted-sets)
- [Key Expiry](#key-expiry)
- [Time Source Abstraction](#time-source-abstraction)
- [Keyspace Notifications](#keyspace-notifications)
- [Pub/Sub System](#pubsub-system)
- [Pattern-Based Subscriptions](#pattern-based-subscriptions)
- [Persistence](#persistence)
  - [High-Level Save/Load](#high-level-saveload)
  - [Low-Level Dump/Restore](#low-level-dumprestore)
- [Creating a Custom Persistence Backend](#creating-a-custom-persistence-backend)
- [Creating a Custom Time Source](#creating-a-custom-time-source)

First, create an instance of Gedis in your script:

```gdscript
# Create a Gedis instance
var gedis = Gedis.new()
# IMPORTANT: Add it to the tree
add_child(gedis)
```

### Strings

```gdscript
# Set and get a value
gedis.set_value("player_name", "Alice")
var name = gedis.get_value("player_name") # "Alice"

# Increment/decrement a numeric value
gedis.set_value("score", 100)
gedis.incrby("score") # 101
gedis.decrby("score") # 99
```

### Hashes

```gdscript
# Store player data in a hash
gedis.hset("player:1", "name", "Bob")
gedis.hset("player:1", "hp", 100)
gedis.hset("player:1", "mana", 50)

# Get a single field
var player_name = gedis.hget("player:1", "name") # "Bob"

# Get all fields as a Dictionary
var player_data = gedis.hgetall("player:1") # {"name": "Bob", "hp": 100, "mana": 50}
```

### Lists

```gdscript
# Use a list as a queue for game events
gedis.rpush("events", "player_spawned")
gedis.rpush("events", "enemy_appeared")

# Process the first event in the queue
var event = gedis.lpop("events") # "player_spawned"
var queue_length = gedis.llen("events") # 1
```

### Sets

```gdscript
# Store unique items a player has collected
gedis.sadd("inventory", "sword")
gedis.sadd("inventory", "shield")
gedis.sadd("inventory", "sword") # This will be ignored

# Check if an item exists
var has_shield = gedis.sismember("inventory", "shield") # true

# Get all items
var all_items = gedis.smembers("inventory") # ["sword", "shield"] or ["shield", "sword"]
```

### Sorted Sets

```gdscript
# Use a sorted set for a leaderboard
gedis.zadd("leaderboard", "Alice", 100)
gedis.zadd("leaderboard", "Bob", 95)
gedis.zadd("leaderboard", "Charlie", 110)

# Get players with scores between 90 and 105
var top_players = gedis.zrange("leaderboard", 90, 105) # ["Bob", "Alice"]
```

### Key Expiry

```gdscript
# Create a temporary key
gedis.set_value("session_token", "xyz123")
gedis.expire("session_token", 60) # Expires in 60 seconds

# Check the remaining time
var time_left = gedis.ttl("session_token") # e.g., 59

# Make the key permanent again
gedis.persist("session_token")
var time_left_after_persist = gedis.ttl("session_token") # -1 (no expiry)
```
### Time Source Abstraction

Gedis now uses a time source abstraction to handle key expiry, making it more flexible for different use cases. The `GedisTimeSource` class provides a unified interface for time, and you can switch between different time sources depending on your needs.

-   `GedisUnixTimeSource` (default): Uses Unix timestamps, which is suitable for most cases.
-   `GedisTickTimeSource`: Uses Godot's internal tick time, which is useful for testing or when you need to control time manually.
-   `GedisProcessDeltaTimeSource`: Uses the delta time from the `_process` function, which is ideal for games that pause.

You can set a different time source using the `set_time_source()` method. Expiry times are now specified in milliseconds.

```gdscript
# Create a new Gedis instance
var gedis = Gedis.new()

# Set a different time source (e.g., tick-based)
var tick_time_source = GedisTickTimeSource.new()
gedis.set_time_source(tick_time_source)

# Set a key to expire in 5 seconds (5000 milliseconds)
gedis.set_value("my_key", "my_value")
gedis.expire("my_key", 5000)
```

### Keyspace Notifications

Gedis now supports keyspace notifications, allowing you to subscribe to events related to specific keys. When a key is set, deleted, or expires, a message is published to a dedicated channel.

The channel format is `gedis:keyspace:<key>`, and the possible messages are `set`, `del`, and `expired`.

```gdscript
# Subscriber script
var gedis = Gedis.new()

func _ready():
    # Subscribe to events for the key "player_health"
    var keyspaced_key := gedis.ks("player_health") # Automatically add the keyspace prefix
    gedis.subscribe(keyspaced_key, self)
    gedis.connect("pubsub_message", _on_keyspace_event)

func _on_keyspace_event(channel, message):
    print("Keyspace event on channel '%s': %s" % [channel, message])

# Publisher script
var gedis = Gedis.new()

func _on_some_event():
    # This will trigger a "set" message
    gedis.set_value("player_health", 100)

    # This will trigger a "del" message
    gedis.del("player_health")
```

### Pub/Sub System

The Pub/Sub system allows for decoupled communication. There are two ways to receive messages:

1.  **Subscriber-based Signals (Recommended):** The subscriber object defines its own `pubsub_message` signal. This is the most robust method as it encapsulates the handling logic within the subscriber.
2.  **Gedis-level Signal:** You can connect to the `pubsub_message` signal on the main Gedis instance. This is useful for global handlers that need to listen to all messages.

**Example with Subscriber-based Signal:**

```gdscript
# Subscriber script
class_name MySubscriber extends Node

# Define the signal that Gedis will emit on this object
signal pubsub_message(channel, message)

var gedis = Gedis.new()

func _ready():
    # Connect to our own signal
    self.pubsub_message.connect(_on_game_event)
    # Subscribe to the 'game_events' channel
    gedis.subscribe("game_events", self)

func _on_game_event(channel, message):
    print("Received message on channel '%s': %s" % [channel, message])

# Publisher script (can be anywhere else)
var gedis = Gedis.new()

func _on_button_pressed():
    # Publish a message to the 'game_events' channel
    gedis.publish("game_events", "Player pressed the button!")
```

### Pattern-Based Subscriptions

Pattern-based subscriptions work similarly. The subscriber object should define a `psub_message` signal.

```gdscript
# PSubscriber script
class_name MyPatternSubscriber extends Node

# Define the signal for pattern-based messages
signal psub_message(pattern, channel, message)

var gedis = Gedis.new()

func _ready():
    # Connect to our own signal
    self.psub_message.connect(_on_player_event)
    # Subscribe to all channels starting with 'player:'
    gedis.psubscribe("player:*", self)

func _on_player_event(pattern, channel, message):
    print("Received message on channel '%s' (matched pattern '%s'): %s" % [channel, pattern, message])

# Publisher script
var gedis = Gedis.new()

func _on_some_event():
    gedis.publish("player:login", "Alice logged in")
    gedis.publish("player:logout", "Bob logged out")
```

## Persistence

Gedis supports persistence, allowing you to save the entire dataset to a file and load it back into memory. This is useful for saving game state, player progress, or any other data that needs to survive between game sessions.

The persistence system is designed to be flexible, with a pluggable backend system. The default backend uses JSON for snapshotting, but you can implement your own backend to support other formats like binary files or databases.

There are two sets of methods for handling persistence:

*   **High-Level API (`save()` and `load()`):** These are the simplest methods to use. They handle the entire process of saving and loading the dataset to a file path you provide.
*   **Low-Level API (`dump()` and `restore()`):** These methods give you more control. `dump()` returns the entire dataset as a serialised object, which you can then handle as you see fit (e.g., send over the network, save to a custom format). `restore()` takes a serialised object and loads it into the Gedis instance.

### Usage Examples

#### High-Level Save/Load

```gdscript
var gedis = Gedis.new()
gedis.set_value("player_name", "Alice")
gedis.set_value("score", 100)

# Save the entire dataset to a file
gedis.save("user://my_save.json")

# Later, in a new instance...
var new_gedis = Gedis.new()
new_gedis.load("user://my_save.json")

var player_name = new_gedis.get_value("player_name") # "Alice"
var score = new_gedis.get_value("score") # 100
```

#### Low-Level Dump/Restore

```gdscript
var gedis = Gedis.new()
gedis.set_value("player_name", "Bob")
gedis.set_value("level", 5)

# Dump the dataset to a variable
var data_dump = gedis.dump_all()

# You can now save `data_dump` to a file, send it over the network, etc.
# For example, save it as a binary file:
var file = FileAccess.open("user://my_data.bin", FileAccess.WRITE)
file.store_var(data_dump)
file.close()

# To restore it...
var new_gedis = Gedis.new()
var file_to_load = FileAccess.open("user://my_data.bin", FileAccess.READ)
var loaded_dump = file_to_load.get_var()
file_to_load.close()

new_gedis.restore_all(loaded_dump)
var player_name = new_gedis.get_value("player_name") # "Bob"
```
### Creating a Custom Persistence Backend

You can create your own persistence backend by extending the `GedisPersistenceBackend` class and implementing the `save` and `load` methods.

```gdscript
class_name MyCustomBackend extends GedisPersistenceBackend

func save(data: Dictionary, options: Dictionary) -> int:
    # Implement your custom save logic here
    # For example, save to a binary file
    var path = options.get("path", "user://gedis.dat")
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        return FAILED
    file.store_var(data)
    file.close()
    return OK

func load(options: Dictionary) -> Dictionary:
    # Implement your custom load logic here
    var path = options.get("path", "user://gedis.dat")
    if not FileAccess.file_exists(path):
        return {}
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return {}
    var data = file.get_var()
    file.close()
    return data
```

### Creating a Custom Time Source

You can create your own time source by extending the `GedisTimeSource` class and implementing the `get_time` method.

```gdscript
class_name MyCustomTimeSource extends GedisTimeSource

var custom_time = 0

func _init(start_time = 0):
    custom_time = start_time

func get_time() -> int:
    # Return the current time in milliseconds
    return custom_time

func advance_time(ms: int):
    custom_time += ms
```