---
layout: default
title: Customizable Time Sources
---

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