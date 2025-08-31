#include "gedis.h"

#include <godot_cpp/core/class_db.hpp>
#include <regex>

using namespace godot;

void Gedis::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set", "key", "value"), &Gedis::set);
    ClassDB::bind_method(D_METHOD("get", "key"), &Gedis::get);
    ClassDB::bind_method(D_METHOD("del", "keys"), &Gedis::del);
    ClassDB::bind_method(D_METHOD("exists", "keys"), &Gedis::exists);
    ClassDB::bind_method(D_METHOD("key_exists", "key"), &Gedis::key_exists);
    ClassDB::bind_method(D_METHOD("incr", "key"), &Gedis::incr);
    ClassDB::bind_method(D_METHOD("decr", "key"), &Gedis::decr);
    ClassDB::bind_method(D_METHOD("keys", "pattern"), &Gedis::keys);

    // Expiry commands
    ClassDB::bind_method(D_METHOD("expire", "key", "seconds"), &Gedis::expire);
    ClassDB::bind_method(D_METHOD("ttl", "key"), &Gedis::ttl);
    ClassDB::bind_method(D_METHOD("persist", "key"), &Gedis::persist);

    // Hash commands
    ClassDB::bind_method(D_METHOD("hset", "key", "field", "value"), &Gedis::hset);
    ClassDB::bind_method(D_METHOD("hget", "key", "field", "default_value"), &Gedis::hget, DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("hgetall", "key"), &Gedis::hgetall);
    ClassDB::bind_method(D_METHOD("hdel", "key", "fields"), &Gedis::hdel);
    ClassDB::bind_method(D_METHOD("hexists", "key", "field"), &Gedis::hexists);
    ClassDB::bind_method(D_METHOD("hkeys", "key"), &Gedis::hkeys);
    ClassDB::bind_method(D_METHOD("hvals", "key"), &Gedis::hvals);
    ClassDB::bind_method(D_METHOD("hlen", "key"), &Gedis::hlen);

    // List commands
    ClassDB::bind_method(D_METHOD("lpush", "key", "values"), &Gedis::lpush);
    ClassDB::bind_method(D_METHOD("rpush", "key", "values"), &Gedis::rpush);
    ClassDB::bind_method(D_METHOD("lpop", "key"), &Gedis::lpop);
    ClassDB::bind_method(D_METHOD("rpop", "key"), &Gedis::rpop);
    ClassDB::bind_method(D_METHOD("llen", "key"), &Gedis::llen);
    ClassDB::bind_method(D_METHOD("lrange", "key", "start", "stop"), &Gedis::lrange);
    ClassDB::bind_method(D_METHOD("lindex", "key", "index"), &Gedis::lindex);
    ClassDB::bind_method(D_METHOD("lset", "key", "index", "value"), &Gedis::lset);
    ClassDB::bind_method(D_METHOD("lrem", "key", "count", "value"), &Gedis::lrem);

    // Set commands
    ClassDB::bind_method(D_METHOD("sadd", "key", "members"), &Gedis::sadd);
    ClassDB::bind_method(D_METHOD("srem", "key", "members"), &Gedis::srem);
    ClassDB::bind_method(D_METHOD("smembers", "key"), &Gedis::smembers);
    ClassDB::bind_method(D_METHOD("sismember", "key", "member"), &Gedis::sismember);
    ClassDB::bind_method(D_METHOD("scard", "key"), &Gedis::scard);
    ClassDB::bind_method(D_METHOD("spop", "key"), &Gedis::spop);
    ClassDB::bind_method(D_METHOD("smove", "source", "destination", "member"), &Gedis::smove);

    // Pub/Sub commands
    ClassDB::bind_method(D_METHOD("publish", "channel", "message"), &Gedis::publish);
    ClassDB::bind_method(D_METHOD("subscribe", "channel", "subscriber"), &Gedis::subscribe);
    ClassDB::bind_method(D_METHOD("unsubscribe", "channel", "subscriber"), &Gedis::unsubscribe);
    ClassDB::bind_method(D_METHOD("psubscribe", "pattern", "subscriber"), &Gedis::psubscribe);
    ClassDB::bind_method(D_METHOD("punsubscribe", "pattern", "subscriber"), &Gedis::punsubscribe);

    ADD_SIGNAL(MethodInfo("pubsub_message", PropertyInfo(Variant::STRING, "channel"), PropertyInfo(Variant::NIL, "message")));
    ADD_SIGNAL(MethodInfo("psub_message", PropertyInfo(Variant::STRING, "pattern"), PropertyInfo(Variant::STRING, "channel"), PropertyInfo(Variant::NIL, "message")));
}

Gedis::Gedis() {
}

Gedis::~Gedis() {
}


void Gedis::set(const String &key, const Variant &value) {
    store.set(key, value);
}

Variant Gedis::get(const String &key) {
    return store.get(key);
}

int64_t Gedis::del(const Array &keys) {
    return store.del(keys);
}

int64_t Gedis::exists(const Array &keys) {
    return store.exists(keys);
}

bool Gedis::key_exists(const String &key) {
    return store.exists(key);
}

Variant Gedis::incr(const String &key) {
    return store.incr(key);
}

Variant Gedis::decr(const String &key) {
    return store.decr(key);
}

TypedArray<String> Gedis::keys(const String &pattern) {
    return store.keys(pattern);
}

// Expiry commands
bool Gedis::expire(const String &key, int64_t seconds) {
    return store.expire(key, seconds);
}

int64_t Gedis::ttl(const String &key) {
    return store.ttl(key);
}

bool Gedis::persist(const String &key) {
    return store.persist(key);
}

// Hash commands
int64_t Gedis::hset(const String &key, const String &field, const Variant &value) {
    return store.hset(key, field, value);
}

Variant Gedis::hget(const String &key, const String &field, const Variant &default_value) {
    return store.hget(key, field, default_value);
}

Dictionary Gedis::hgetall(const String &key) {
    return store.hgetall(key);
}

int64_t Gedis::hdel(const String &key, const Variant &fields) {
    return store.hdel(key, fields);
}

bool Gedis::hexists(const String &key, const String &field) {
    return store.hexists(key, field);
}

Array Gedis::hkeys(const String &key) {
    return store.hkeys(key);
}

Array Gedis::hvals(const String &key) {
    return store.hvals(key);
}

int64_t Gedis::hlen(const String &key) {
    return store.hlen(key);
}

// List commands
int64_t Gedis::lpush(const String &key, const Variant &values) {
    return store.lpush(key, values);
}

int64_t Gedis::rpush(const String &key, const Variant &values) {
    return store.rpush(key, values);
}

Variant Gedis::lpop(const String &key) {
    return store.lpop(key);
}

Variant Gedis::rpop(const String &key) {
    return store.rpop(key);
}

int64_t Gedis::llen(const String &key) {
    return store.llen(key);
}

Array Gedis::lrange(const String &key, int64_t start, int64_t stop) {
    return store.lrange(key, start, stop);
}

Variant Gedis::lindex(const String &key, int64_t index) {
    return store.lindex(key, index);
}

bool Gedis::lset(const String &key, int64_t index, const Variant &value) {
    return store.lset(key, index, value);
}

int64_t Gedis::lrem(const String &key, int64_t count, const Variant &value) {
    return store.lrem(key, count, value);
}

// Set commands
int64_t Gedis::sadd(const String &key, const Variant &members) {
    return store.sadd(key, members);
}

int64_t Gedis::srem(const String &key, const Variant &members) {
    return store.srem(key, members);
}

Array Gedis::smembers(const String &key) {
    return store.smembers(key);
}

bool Gedis::sismember(const String &key, const Variant &member) {
    return store.sismember(key, member);
}

int64_t Gedis::scard(const String &key) {
    return store.scard(key);
}

Variant Gedis::spop(const String &key) {
    return store.spop(key);
}

bool Gedis::smove(const String &source, const String &destination, const Variant &member) {
    return store.smove(source, destination, member);
}

// Pub/Sub commands
void Gedis::publish(const String &channel, const Variant &message) {
    // Direct subscribers
    for (Object *subscriber : store.get_subscribers(channel)) {
        subscriber->emit_signal("pubsub_message", channel, message);
    }

    // Pattern subscribers
    for (const auto& [pattern, subscribers] : store.get_psubscribers()) {
        std::string pattern_str = pattern;
        std::string channel_str = channel.utf8().get_data();
        
        // Convert glob to regex
        std::string regex_pattern = "";
        for (char c : pattern_str) {
            switch (c) {
                case '*':
                    regex_pattern += ".*";
                    break;
                case '?':
                    regex_pattern += ".";
                    break;
                default:
                    regex_pattern += c;
                    break;
            }
        }

        if (std::regex_match(channel_str, std::regex(regex_pattern))) {
            for (Object *subscriber : subscribers) {
                subscriber->emit_signal("psub_message", String(pattern.c_str()), channel, message);
            }
        }
    }
}

void Gedis::subscribe(const String &channel, Object *subscriber) {
    store.subscribe(channel, subscriber);
}

void Gedis::unsubscribe(const String &channel, Object *subscriber) {
    store.unsubscribe(channel, subscriber);
}

void Gedis::psubscribe(const String &pattern, Object *subscriber) {
    store.psubscribe(pattern, subscriber);
}

void Gedis::punsubscribe(const String &pattern, Object *subscriber) {
    store.punsubscribe(pattern, subscriber);
}