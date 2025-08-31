# Gedis GDExtension

<img width="512" height="512" alt="image" src="https://github.com/user-attachments/assets/7724b2b2-2d63-4786-9078-8123aca0bb2d" />

An in-memory, Redis-like datastore for Godot, implemented as a GDExtension.

## Overview

Gedis is a high-performance, in-memory key-value datastore for Godot projects, inspired by Redis. It provides a rich set of data structures and commands, accessible directly from GDScript. As a GDExtension, it runs with native C++ speed, making it suitable for performance-critical applications. Gedis is designed as an easy-to-use, autoloaded singleton, so you can access it from anywhere in your project: `Gedis.set_value("score", 10)`.

## Features

- **Strings**: Basic key-value storage (`set`, `get`, `incr`, `decr`).
- **Hashes**: Store object-like structures with fields and values (`hset`, `hget`, `hgetall`).
- **Lists**: Ordered collections of strings, useful for queues and stacks (`lpush`, `rpush`, `lpop`).
- **Sets**: Unordered collections of unique strings (`sadd`, `srem`, `smembers`).
- **Key Expiry**: Set a time-to-live (TTL) on keys for automatic deletion (`expire`, `ttl`).
- **Pub/Sub**: A powerful publish-subscribe system for real-time messaging between different parts of your game (`publish`, `subscribe`).

## Build Instructions

To compile the Gedis GDExtension from source, follow these steps:

1.  **Clone the repository**:

    ```sh
    git clone --recursive https://github.com/your-username/gedis.git
    cd gedis
    ```

    _Note: If you cloned without `--recursive`, you can initialize the submodule separately:_

    ```sh
    git submodule update --init --recursive
    ```

2.  **Compile with SCons**:
    You will need SCons and a C++ compiler (like GCC, Clang, or MSVC) installed.
    ```sh
    scons
    ```
    This will build the GDExtension and place the compiled library in the `addons/Gedis/bin/` directory.

## Installation

1.  Copy the entire `addons/Gedis` folder into your Godot project's `addons` directory.
2.  In Godot, go to **Project -> Project Settings -> Plugins** and enable the "Gedis" plugin.
3.  The plugin will register an autoloaded singleton named `Gedis`, which is now available globally in your scripts.

## Usage Examples

### Strings

```gdscript
# Set and get a value
Gedis.set_value("player_name", "Alice")
var name = Gedis.get_value("player_name") # "Alice"

# Increment/decrement a numeric value
Gedis.set_value("score", 100)
Gedis.incr("score") # 101
Gedis.decrby("score", 10) # 91
```

### Hashes

```gdscript
# Store player data in a hash
Gedis.hset("player:1", "name", "Bob")
Gedis.hset("player:1", "hp", 100)
Gedis.hset("player:1", "mana", 50)

# Get a single field
var player_name = Gedis.hget("player:1", "name") # "Bob"

# Get all fields as a Dictionary
var player_data = Gedis.hgetall("player:1") # {"name": "Bob", "hp": 100, "mana": 50}
```

### Lists

```gdscript
# Use a list as a queue for game events
Gedis.rpush("events", "player_spawned")
Gedis.rpush("events", "enemy_appeared")

# Process the first event in the queue
var event = Gedis.lpop("events") # "player_spawned"
var queue_length = Gedis.llen("events") # 1
```

### Sets

```gdscript
# Store unique items a player has collected
Gedis.sadd("inventory", "sword")
Gedis.sadd("inventory", "shield")
Gedis.sadd("inventory", "sword") # This will be ignored

# Check if an item exists
var has_shield = Gedis.sismember("inventory", "shield") # true

# Get all items
var all_items = Gedis.smembers("inventory") # ["sword", "shield"] or ["shield", "sword"]
```

### Key Expiry

```gdscript
# Create a temporary key
Gedis.set_value("session_token", "xyz123")
Gedis.expire("session_token", 60) # Expires in 60 seconds

# Check the remaining time
var time_left = Gedis.ttl("session_token") # e.g., 59

# Make the key permanent again
Gedis.persist("session_token")
var time_left_after_persist = Gedis.ttl("session_token") # -1 (no expiry)
```

### Pub/Sub System

The Pub/Sub system allows for decoupled communication using signals.

```gdscript
# Subscriber script
func _ready():
    # Subscribe to the 'game_events' channel and connect to a local method
    Gedis.subscribe("game_events", _on_game_event)

func _on_game_event(channel, message):
    print("Received message on channel '%s': %s" % [channel, message])

# Publisher script (can be anywhere else)
func _on_button_pressed():
    # Publish a message to the 'game_events' channel
    Gedis.publish("game_events", "Player pressed the button!")
```

## API Reference

| Method                           | Description                                                |
| -------------------------------- | ---------------------------------------------------------- |
| **Strings**                      |                                                            |
| `set_value(key, value)`          | Sets the string value of a key.                            |
| `get_value(key)`                 | Gets the string value of a key.                            |
| `del(key)`                       | Deletes a key.                                             |
| `exists(key)`                    | Checks if a key exists.                                    |
| `incr(key)`                      | Increments the integer value of a key by one.              |
| `incrby(key, amount)`            | Increments the integer value of a key by the given amount. |
| `decr(key)`                      | Decrements the integer value of a key by one.              |
| `decrby(key, amount)`            | Decrements the integer value of a key by the given amount. |
| **Hashes**                       |                                                            |
| `hset(key, field, value)`        | Sets the string value of a hash field.                     |
| `hget(key, field)`               | Gets the value of a hash field.                            |
| `hgetall(key)`                   | Gets all the fields and values in a hash as a Dictionary.  |
| `hdel(key, field)`               | Deletes a hash field.                                      |
| `hkeys(key)`                     | Gets all the fields in a hash.                             |
| `hvals(key)`                     | Gets all the values in a hash.                             |
| `hlen(key)`                      | Gets the number of fields in a hash.                       |
| **Lists**                        |                                                            |
| `lpush(key, value)`              | Prepends one value to a list.                              |
| `rpush(key, value)`              | Appends one value to a list.                               |
| `lpop(key)`                      | Removes and gets the first element in a list.              |
| `rpop(key)`                      | Removes and gets the last element in a list.               |
| `llen(key)`                      | Gets the length of a list.                                 |
| `lrange(key, start, stop)`       | Gets a range of elements from a list.                      |
| **Sets**                         |                                                            |
| `sadd(key, member)`              | Adds one member to a set.                                  |
| `srem(key, member)`              | Removes one member from a set.                             |
| `smembers(key)`                  | Gets all the members in a set.                             |
| `sismember(key, member)`         | Checks if a member is in a set.                            |
| `scard(key)`                     | Gets the number of members in a set.                       |
| **Expiry**                       |                                                            |
| `expire(key, seconds)`           | Sets a key's time to live in seconds.                      |
| `ttl(key)`                       | Gets the remaining time to live of a key.                  |
| `persist(key)`                   | Removes the expiration from a key.                         |
| **Pub/Sub**                      |                                                            |
| `publish(channel, message)`      | Posts a message to a channel.                              |
| `subscribe(channel, callable)`   | Subscribes the client to the given channel.                |
| `unsubscribe(channel, callable)` | Unsubscribes the client from the given channel.            |

## License

MIT — see LICENSE for details.
