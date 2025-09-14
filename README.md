# Gedis

<p align="center">
    <img width="512" height="512" alt="image" src="https://github.com/NodotProject/gedis/blob/main/addons/Gedis/icon.png?raw=true" />
</p>

<p align="center">
    An in-memory, Redis-like datastore for Godot.
</p>

[![](https://dcbadge.vercel.app/api/server/Rx9CZX4sjG)](https://discord.gg/Rx9CZX4sjG) [![](https://img.shields.io/mastodon/follow/110106863700290562?domain=https%3A%2F%2Fmastodon.gamedev.place&label=MASTODON&style=for-the-badge)](https://mastodon.gamedev.place/@krazyjakee) [![](https://img.shields.io/youtube/channel/subscribers/UColWkNMgHseKyU7D1QGeoyQ?label=YOUTUBE&style=for-the-badge)](https://www.youtube.com/@GodotNodot)

![Stats](https://repobeats.axiom.co/api/embed/2a34f9ee10e86a04db97091d90c892c07c8314d1.svg "Repobeats analytics image")

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
    - [Strings](#strings)
    - [Hashes](#hashes)
    - [Lists](#lists)
    - [Sets](#sets)
    - [Sorted Sets](#sorted-sets)
    - [Key Expiry](#key-expiry)
    - [Pub/Sub System](#pubsub-system)
    - [Pattern-Based Subscriptions](#pattern-based-subscriptions)
- [Persistence](#persistence)
    - [Usage Examples](#usage-examples-1)
    - [High-Level Save/Load](#high-level-saveload)
    - [Low-Level Dump/Restore](#low-level-dumprestore)
- [Customizable Time Sources](#customizable-time-sources)
- [Debugger](#debugger)
- [API Reference](#api-reference)
- [Contribution Instructions](#contribution-instructions)
- [License](#license)

## Overview

Gedis is a high-performance, in-memory key-value datastore for Godot projects, inspired by Redis. It provides a rich set of data structures and commands. Simply create an instance with `var gedis = Gedis.new()` and start using it: `gedis.set_value("score", 10)`.

[![Video preview](video.png)](https://www.youtube.com/watch?v=tjiwAmH2-mE)

**Redis-like? What the heck is Redis?** - See [Redis in 100 Seconds](https://www.youtube.com/watch?v=G1rOthIU-uo).

## Features

- **Strings**: Basic key-value storage (`set_value`, `get_value`, `incr`, `decr`).
- **Hashes**: Store object-like structures with fields and values (`hset`, `hget`, `hgetall`).
- **Lists**: Ordered collections of strings, useful for queues and stacks (`lpush`, `rpush`, `lpop`).
- **Sets**: Unordered collections of unique strings (`sadd`, `srem`, `smembers`).
- **Key Expiry**: Set a time-to-live (TTL) on keys for automatic deletion (`expire`, `ttl`).
- **Pub/Sub**: A powerful publish-subscribe system for real-time messaging between different parts of your game (`publish`, `subscribe`).
- **Sorted Sets**: Ordered collections of unique strings where each member has an associated score (`zadd`, `zrem`, `zrange`).

## Installation

1.  Copy the entire `addons/Gedis` folder into your Godot project's `addons` directory.
2.  In Godot, go to **Project -> Project Settings -> Plugins** and enable the "Gedis" plugin.
3.  The plugin will register an autoloaded singleton named `Gedis`, which is now available globally in your scripts.

## Usage Examples

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

## Customizable Time Sources

Gedis uses a time source system to handle key expiry, which allows you to customize how time is measured. This is particularly useful for testing or for synchronizing with different in-game or real-world clocks. By default, Gedis uses `GedisUnixTimeSource`, which is based on the system's UNIX timestamp.

You can set a new time source at any time using the `set_time_source()` method.

### GedisUnixTimeSource (Default)

This time source uses the real-world UNIX timestamp (`Time.get_unix_time_from_system()`). It is the default and is suitable for most applications where expiry should be tied to real-world time.

```gdscript
var gedis = Gedis.new()
# No need to set it, as it's the default.
# But if you wanted to be explicit:
gedis.set_time_source(GedisUnixTimeSource.new())
```

### GedisProcessDeltaTimeSource

This time source is based on the elapsed game time since the project started, and it respects `Engine.time_scale`. This is useful if you want key expiry to be tied to in-game time, which might be paused or slowed down.

```gdscript
var gedis = Gedis.new()
gedis.set_time_source(GedisProcessDeltaTimeSource.new())

gedis.set_value("power_up", "double_points")
gedis.expire("power_up", 10) # Expires in 10 seconds of in-game time
```

### GedisTickTimeSource

This time source measures time in ticks, where each tick is a frame. It's useful for scenarios where you want expiry to be based on a specific number of frames rather than seconds.

```gdscript
var gedis = Gedis.new()
gedis.set_time_source(GedisTickTimeSource.new())

gedis.set_value("temporary_effect", "active")
gedis.expire("temporary_effect", 300) # Expires after 300 frames
```

## Debugger

Gedis comes with a debugger interface!

![Gedis Debugger](debugger.png)

## API Reference

| Method                           | Description                                                |
| -------------------------------- | ---------------------------------------------------------- |
| **Strings**                      |                                                            |
| `set_value(key, value)`          | Sets the value of a key.                            |
| `get_value(key)`                 | Gets the value of a key.                            |
| `del(keys)`                      | Deletes one or more keys (accepts Array).                  |
| `exists(keys)`                   | Checks if keys exist (accepts Array).                      |
| `key_exists(key)`                | Checks if a single key exists.                             |
| `incr(key)`                      | Increments the integer value of a key by one.              |
| `decr(key)`                      | Decrements the integer value of a key by one.              |
| `keys(pattern)`                  | Gets all keys matching a pattern.                          |
| **Hashes**                       |                                                            |
| `hset(key, field, value)`        | Sets the string value of a hash field.                     |
| `hget(key, field, default)`      | Gets the value of a hash field with optional default.      |
| `hgetall(key)`                   | Gets all the fields and values in a hash as a Dictionary.  |
| `hdel(key, fields)`              | Deletes hash fields (accepts single field or Array).       |
| `hexists(key, field)`            | Checks if a hash field exists.                             |
| `hkeys(key)`                     | Gets all the fields in a hash.                             |
| `hvals(key)`                     | Gets all the values in a hash.                             |
| `hlen(key)`                      | Gets the number of fields in a hash.                       |
| **Lists**                        |                                                            |
| `lpush(key, values)`             | Prepends values to a list. If `values` is an Array, it's concatenated. |
| `rpush(key, values)`             | Appends values to a list. If `values` is an Array, it's concatenated. |
| `lpop(key)`                      | Removes and gets the first element in a list.              |
| `rpop(key)`                      | Removes and gets the last element in a list.               |
| `llen(key)`                      | Gets the length of a list.                                 |
| `lget(key)`                      | Gets all elements from a list.                             |
| `lrange(key, start, stop)`       | Gets a range of elements from a list.                      |
| `lindex(key, index)`             | Gets an element from a list by index.                      |
| `lset(key, index, value)`        | Sets the value of a list element by index.                 |
| `lrem(key, count, value)`        | Removes elements from a list.                              |
| **Sets**                         |                                                            |
| `sadd(key, members)`             | Adds members to a set (accepts single member or Array).    |
| `srem(key, members)`             | Removes members from a set (accepts single member or Array).|
| `smembers(key)`                  | Gets all the members in a set.                             |
| `sismember(key, member)`         | Checks if a member is in a set.                            |
| `scard(key)`                     | Gets the number of members in a set.                       |
| `spop(key)`                      | Removes and returns a random member from a set.            |
| `smove(source, dest, member)`    | Moves a member from one set to another.                    |
| **Sorted Sets**                  |                                                            |
| `zadd(key, member, score)`       | Adds a member with a score to a sorted set.                |
| `zrem(key, member)`              | Removes a member from a sorted set.                        |
| `zrange(key, min, max)`   | Gets members from a sorted set within a score range.       |
| `zrevrange(key, start, stop, withscores=false)` | Returns the specified range of elements in the sorted set stored at `key`, with scores ordered from high to low. |
| `zpopready(key, now)`            | Removes and returns members with scores up to a value.     |
| **Expiry**                       |                                                            |
| `expire(key, seconds)`           | Sets a key's time to live in seconds.                      |
| `setex(key, seconds, value)`     | Set `key` to hold `value` and set `key` to timeout after a given number of `seconds`. |
| `ttl(key)`                       | Gets the remaining time to live of a key.                  |
| `persist(key)`                   | Removes the expiration from a key.                         |
| **Pub/Sub**                      |                                                            |
| `publish(channel, message)`      | Posts a message to a channel.                              |
| `subscribe(channel, subscriber)` | Subscribes an object to the given channel.                 |
| `unsubscribe(channel, subscriber)` | Unsubscribes an object from the given channel.           |
| `psubscribe(pattern, subscriber)` | Subscribes to channels matching a pattern.                |
| `punsubscribe(pattern, subscriber)` | Unsubscribes from channels matching a pattern.          |
| **Persistence**                  |                                                            |
| `save(path, backend)`            | Saves the entire dataset to a file using a specific backend. |
| `load(path, backend)`            | Loads the dataset from a file.                             |
| `dump(backend)`                  | Dumps the dataset to a serialised object.                  |
| `restore(data, backend)`         | Restores the dataset from a serialised object.             |

## Contribution Instructions

This addon is implemented in GDScript and does not require native compilation. To work on or test the addon, follow these steps:

1.  **Clone the repository**:

    ```sh
    git clone --recursive https://github.com/NodotProject/Gedis.git
    cd Gedis
    ```

2.  **Develop & Test**:

    - The addon code lives under `addons/Gedis`. Copy that folder into your Godot project's `addons` directory to test changes.
    - Run the project's test suite with `./run_tests.sh`.

3.  **Contribute**:

    Create a branch, make your changes, and open a pull request describing the work.

## License

MIT — see LICENSE for details.
