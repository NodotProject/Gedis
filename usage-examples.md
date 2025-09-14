---
layout: page
title: Usage Examples
permalink: usage-examples
---

First, create an instance of Gedis in your script:

```gdscript
# Create a Gedis instance
var gedis = Gedis.new()
```

### Strings

```gdscript
# Set and get a value
gedis.set_value("player_name", "Alice")
var name = gedis.get_value("player_name") # "Alice"

# Increment/decrement a numeric value
gedis.set_value("score", 100)
gedis.incr("score") # 101
gedis.decr("score") # 99
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

### Pub/Sub System

The Pub/Sub system allows for decoupled communication using signals.

```gdscript
# Subscriber script
var gedis = Gedis.new()

func _ready():
    # Subscribe to the 'game_events' channel and connect to a local method
    gedis.subscribe("game_events", self)
    gedis.connect("pubsub_message", _on_game_event)

func _on_game_event(channel, message):
    print("Received message on channel '%s': %s" % [channel, message])

# Publisher script (can be anywhere else)
var gedis = Gedis.new()

func _on_button_pressed():
    # Publish a message to the 'game_events' channel
    gedis.publish("game_events", "Player pressed the button!")
   ```
   
   ### Pattern-Based Subscriptions
   
   You can also subscribe to channels that match a specific pattern.
   
   ```gdscript
   # PSubscriber script
   var gedis = Gedis.new()
   
   func _ready():
    # Subscribe to all channels starting with 'player:'
    gedis.psubscribe("player:*", self)
    gedis.connect("psub_message", _on_player_event)
   
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
var data_dump = gedis.dump()

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

new_gedis.restore(loaded_dump)
var player_name = new_gedis.get_value("player_name") # "Bob"
```