---
layout: default
title: Pub/Sub System
---

## Pub/Sub System

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