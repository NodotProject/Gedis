---
layout: home
title: Home
permalink: /
---

<p align="center">
    <img width="512" height="512" alt="image" src="https://github.com/NodotProject/gedis/blob/main/addons/Gedis/icon.png?raw=true" />
</p>

<p align="center">
    An in-memory, Redis-like datastore for Godot.
</p>

<p align="center">
    <a href="https://discord.gg/Rx9CZX4sjG"><img class="inline" src="https://img.shields.io/discord/1089846386566111322" alt="Discord"></a>
    <a href="https://mastodon.gamedev.place/@krazyjakee"><img class="inline" src="https://img.shields.io/mastodon/follow/110106863700290562?domain=mastodon.gamedev.place" alt="Mastodon"></a>
    <a href="https://www.youtube.com/@GodotNodot"><img class="inline" src="https://img.shields.io/youtube/channel/subscribers/UColWkNMgHseKyU7D1QGeoyQ" alt="Youtube"></a>
    <a href="https://github.com/sponsors/krazyjakee"><img class="inline" src="https://img.shields.io/github/sponsors/krazyjakee" alt="GitHub Sponsors"></a>
    <a href="https://github.com/NodotProject/Gedis"><img class="inline" src="https://img.shields.io/github/stars/NodotProject/Gedis" alt="GitHub Stars"></a>
</p>

![Stats](https://repobeats.axiom.co/api/embed/2a34f9ee10e86a04db97091d90c892c07c8314d1.svg "Repobeats analytics image")

## Overview

Gedis is a high-performance, in-memory key-value datastore for Godot projects, inspired by Redis. It provides a rich set of data structures and commands. Simply create an instance with `var gedis = Gedis.new()` and start using it: `gedis.set_value("score", 10)`.

[![Video preview](video.png)](https://www.youtube.com/watch?v=tjiwAmH2-mE)

**Redis-like? What the heck is Redis?** - See [Redis in 100 Seconds](https://www.youtube.com/watch?v=G1rOthIU-uo).

## Features

- **Variants**: Basic key-value storage (`set_value`, `get_value`, `incr`, `decr`, `mget`, `mset`).
- **Hashes**: Store object-like structures with fields and values (`hset`, `hget`, `hgetall`, `hmget`, `hmset`).
- **Lists**: Ordered collections of strings, useful for queues and stacks (`lpush`, `rpush`, `lpop`, `blpop`, `ltrim`).
- **Sets**: Unordered collections of unique strings (`sadd`, `srem`, `smembers`, `sunion`, `sinter`).
- **Key Expiry**: Set a time-to-live (TTL) on keys for automatic deletion (`expire`, `ttl`).
- **Pub/Sub**: A powerful publish-subscribe system for real-time messaging between different parts of your game (`publish`, `subscribe`).
- **Sorted Sets**: Ordered collections of unique strings where each member has an associated score (`zadd`, `zrem`, `zrange`, `zscore`, `zrank`).

## Debugger

Gedis comes with a debugger interface!

![Gedis Debugger](debugger.png)

## 💖 Support Me
Hi! I’m krazyjakee 🎮, creator and maintain­er of the *NodotProject* - a suite of open‑source Godot tools (e.g. Nodot, Gedis etc) that empower game developers to build faster and maintain cleaner code.

I’m looking for sponsors to help sustain and grow the project: more dev time, better docs, more features, and deeper community support. Your support means more stable, polished tools used by indie makers and studios alike.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/krazyjakee)

Every contribution helps maintain and improve this project. And encourage me to make more projects like this!

*This is optional support. The tool remains free and open-source regardless.*

---

**Created with ❤️ for Godot Developers**  
For contributions, please open issues on GitHub