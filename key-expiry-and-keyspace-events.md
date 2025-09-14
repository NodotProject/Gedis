---
layout: default
title: Key Expiry & Keyspace Events
---

## Key Expiry & Keyspace Events

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

### Keyspace Events

Gedis can publish events when keys are created, modified, or deleted, allowing you to react to changes in your data. This is part of the Pub/Sub system. The following events are available:

*   `set`: Published when a key is created or overwritten.
*   `del`: Published when a key is deleted.
*   `expired`: Published when a key's TTL runs out.

Events are published to the channel `gedis:keyspace:<key_name>`.

```gdscript
# Subscribe to the expiry event for a specific key
gedis.subscribe("gedis:keyspace:my_temporary_key", self)
gedis.connect("pubsub_message", _on_key_expired)

func _on_key_expired(channel, message):
   match message:
        "set":
            print("Key was set!")
        "del":
            print("Key was deleted!")
        "expired":
            print("Key has expired!")

# Set a key with a short expiry
gedis.setex("my_temporary_key", 1, "some_value")