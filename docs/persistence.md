---
layout: default
title: Persistence
---

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