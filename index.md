---
layout: home
title: Home
permalink: /
---

# Gedis

<p align="center">
    <img width="512" height="512" alt="image" src="https://github.com/NodotProject/gedis/blob/main/addons/Gedis/icon.png?raw=true" />
</p>

<p align="center">
    An in-memory, Redis-like datastore for Godot.
</p>

[![](https://dcbadge.vercel.app/api/server/Rx9CZX4sjG)](https://discord.gg/Rx9CZX4sjG) [![](https://img.shields.io/mastodon/follow/110106863700290562?domain=https%3A%2F%2Fmastodon.gamedev.place&label=MASTODON&style=for-the-badge)](https://mastodon.gamedev.place/@krazyjakee) [![](https://img.shields.io/youtube/channel/subscribers/UColWkNMgHseKyU7D1QGeoyQ?label=YOUTUBE&style=for-the-badge)](https://www.youtube.com/@GodotNodot)

![Stats](https://repobeats.axiom.co/api/embed/2a34f9ee10e86a04db97091d90c892c07c8314d1.svg "Repobeats analytics image")

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
