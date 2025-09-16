---
layout: page
title: API Reference
permalink: api-reference
---

| Method                           | Description                                                |
| -------------------------------- | ---------------------------------------------------------- |
| **Keys**                         |                                                            |
| `flushall()`                     | Deletes all keys from the database.                        |
| `flushdb()`                      | Deletes all keys from the database. Alias for `flushall`.  |
| `type(key)`                      | Returns the string representation of the type of the value stored at `key`. The different types that can be returned are: `string`, `list`, `set`, `zset`, `hash` and `stream`. |
| `renamenx(key, new_key)`         | Renames `key` to `new_key`, only if `new_key` does not exist. |
| `randomkey()`                    | Returns a random key from the currently selected database. |
| `dbsize()`                       | Returns the number of keys in the currently selected database. |
| **Strings**                      |                                                            |
| `set_value(key, value)`          | Sets the value of a key.                                   |
| `get_value(key)`                 | Gets the value of a key.                                   |
| `del(keys)`                      | Deletes one or more keys (accepts Array).                  |
| `exists(keys)`                   | Checks if keys exist (accepts Array).                      |
| `key_exists(key)`                | Checks if a single key exists.                             |
| `incrby(key)`                      | Increments the integer value of a key by one.              |
| `decrby(key)`                      | Decrements the integer value of a key by one.              |
| `mget(keys)`                     | Returns the values of all specified keys. For every key that does not hold a string value or does not exist, a `null` value is returned. |
| `mset(values)`                   | Sets the given keys to their respective values. `MSET` replaces existing values with new values, just as regular `SET`. |
| `append(key, value)`             | If `key` already exists and is a string, this command appends the `value` at the end of the string. If `key` does not exist it is created and set as an empty string, so `APPEND` will be similar to `SET` in this special case. |
| `getset(key, value)`             | Atomically sets `key` to `value` and returns the old value stored at `key`. |
| `strlen(key)`                    | Returns the length of the string value stored at `key`. An error is returned when `key` holds a non-string value. |
| `incrby(key, amount)`            | Increments the integer value of a key by the given `amount`. |
| `decrby(key, amount)`            | Decrements the integer value of a key by the given `amount`. |
| `setnx(key, value)`              | Sets `key` to hold `value` only if `key` does not exist. |
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
| `hmget(key, fields)`             | Returns the values associated with the specified `fields` in the hash stored at `key`. |
| `hmset(key, values)`             | Sets the specified `fields` to their respective `values` in the hash stored at `key`. This command overwrites any existing fields in the hash. |
| `hincrby(key, field, amount)`    | Increments the integer value of a hash `field` by the given `amount`. |
| `hincrbyfloat(key, field, amount)`| Increments the float value of a hash `field` by the given `amount`. |
| **Lists**                        |                                                            |
| `lpush(key, values)`             | Prepends values to a list. If `values` is an Array, it's concatenated. |
| `rpush(key, values)`             | Appends values to a list. If `values` is an Array, it's concatenated. |
| `lpop(key)`                      | Removes and gets the first element in a list.              |
| `rpop(key)`                      | Removes and gets the last element in a list.               |
| `lmove(source, destination, from, to)` | Atomically pops an element from one end of a source list and pushes it to one end of a destination list. Directions (`from` and `to`, which can be `LEFT` or `RIGHT`) specify which side to pop from and which side to push to. Returns the moved element or `null` if the source is empty. Creates the destination list if it doesn’t exist. This command replaces the deprecated `RPOPLPUSH` command. |
| `llen(key)`                      | Gets the length of a list.                                 |
| `lget(key)`                      | Gets all elements from a list.                             |
| `lrange(key, start, stop)`       | Gets a range of elements from a list.                      |
| `lindex(key, index)`             | Gets an element from a list by index.                      |
| `lset(key, index, value)`        | Sets the value of a list element by index.                 |
| `lrem(key, count, value)`        | Removes elements from a list.                              |
| `blpop(keys, timeout)`           | A blocking list pop primitive. It is the blocking version of `LPOP`. |
| `brpop(keys, timeout)`           | A blocking list pop primitive. It is the blocking version of `RPOP`. |
| `brpoplpush(source, destination, timeout)` | A blocking list pop and push primitive. It is the blocking version of `RPOPLPUSH`. |
| `ltrim(key, start, stop)`        | Trims an existing list so that it will contain only the specified range of elements specified. |
| `linsert(key, where, pivot, value)` | Inserts `value` in the list stored at `key`, either before or after the reference value `pivot`. |
| **Sets**                         |                                                            |
| `sadd(key, members)`             | Adds members to a set (accepts single member or Array).    |
| `srem(key, members)`             | Removes members from a set (accepts single member or Array).|
| `smembers(key)`                  | Gets all the members in a set.                             |
| `sismember(key, member)`         | Checks if a member is in a set.                            |
| `scard(key)`                     | Gets the number of members in a set.                       |
| `spop(key)`                      | Removes and returns a random member from a set.            |
| `smove(source, dest, member)`    | Moves a member from one set to another.                    |
| `sunion(keys)`                   | Returns the members of the set resulting from the union of all the given sets. |
| `sinter(keys)`                   | Returns the members of the set resulting from the intersection of all the given sets. |
| `sdiff(keys)`                    | Returns the members of the set resulting from the difference between the first set and all the successive sets. |
| `sunionstore(destination, keys)` | This command is equal to `SUNION`, but instead of returning the resulting set, it is stored in `destination`. |
| `sinterstore(destination, keys)` | This command is equal to `SINTER`, but instead of returning the resulting set, it is stored in `destination`. |
| `sdiffstore(destination, keys)`  | This command is equal to `SDIFF`, but instead of returning the resulting set, it is stored in `destination`. |
| `srandmember(key, count)`        | When called with just the `key` argument, return a random element from the set value stored at `key`. |
| **Sorted Sets**                  |                                                            |
| `zadd(key, member, score)`       | Adds a member with a score to a sorted set.                |
| `zrem(key, member)`              | Removes a member from a sorted set.                        |
| `zrange(key, start, stop, withscores=false)`   | Gets members from a sorted set within a range of indices (rank). This is not to be confused with `ZRANGEBYSCORE` which operates on scores. |
| `zrevrange(key, start, stop, withscores=false)` | Returns the specified range of elements in the sorted set stored at `key`, with scores ordered from high to low. |
| `zpopready(key, now)`            | Removes and returns members with scores up to a value.     |
| `zscore(key, member)`            | Returns the score of `member` in the sorted set at `key`.  |
| `zrank(key, member)`             | Returns the rank of `member` in the sorted set stored at `key`, with the scores ordered from low to high. |
| `zrevrank(key, member)`          | Returns the rank of `member` in the sorted set stored at `key`, with the scores ordered from high to low. |
| `zcount(key, min, max)`          | Returns the number of elements in the sorted set at `key` with a score between `min` and `max`. |
| `zincrby(key, increment, member)`| Increments the score of `member` in the sorted set stored at `key` by `increment`. |
| `zrangebyscore(key, min, max)`   | Returns all the elements in the sorted set at `key` with a score between `min` and `max`. |
| `zrevrangebyscore(key, max, min)`| Returns all the elements in the sorted set at `key` with a score between `max` and `min`. |
| `zunionstore(destination, keys)` | Computes the union of the given sorted sets and stores the result in `destination`. |
| `zinterstore(destination, keys)` | Computes the intersection of the given sorted sets and stores the result in `destination`. |
| **Expiry**                       |                                                            |
| `expire(key, milliseconds)`      | Sets a key's time to live in milliseconds.                 |
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
| **Time Source**                  |                                                            |
| `set_time_source(time_source)`   | Sets the time source for key expiry.                       |