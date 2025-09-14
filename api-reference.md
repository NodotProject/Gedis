---
layout: default
title: API Reference
---

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