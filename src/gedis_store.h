#ifndef GEDIS_STORE_H
#define GEDIS_STORE_H

#include "gedis_object.h"
#include <unordered_map>
#include <string>

// Forward declarations for Godot types
namespace godot {
    class String;
    class Variant;
    class Array;
    class Dictionary;
    template<typename T> class TypedArray;
    class Object;
}

class GedisStore {
private:
    std::unordered_map<std::string, GedisObject*> store;
    std::unordered_map<std::string, std::vector<godot::Object*>> subscriptions;
    std::unordered_map<std::string, std::vector<godot::Object*>> psubscriptions;

public:
    GedisStore();
    ~GedisStore();

    void set(const godot::String& key, const godot::Variant& value);
    godot::Variant get(const godot::String& key);
    int64_t del(const godot::Array& keys);
    int64_t exists(const godot::Array& keys);
    bool exists(const godot::String& key);
    godot::Variant incr(const godot::String& key);
    godot::Variant decr(const godot::String& key);
    godot::TypedArray<godot::String> keys(const godot::String& pattern);
    void remove_expired_keys();

    // Debugger commands
    godot::String type(const godot::String &key);
    godot::Dictionary dump(const godot::String &key);
    godot::Dictionary snapshot(const godot::String &pattern);

    // Expiry commands
    bool expire(const godot::String &key, int64_t seconds);
    int64_t ttl(const godot::String &key);
    bool persist(const godot::String &key);

    // Hash commands
    int64_t hset(const godot::String &key, const godot::String &field, const godot::Variant &value);
    godot::Variant hget(const godot::String &key, const godot::String &field, const godot::Variant &default_value);
    godot::Dictionary hgetall(const godot::String &key);
    int64_t hdel(const godot::String &key, const godot::Variant &fields);
    bool hexists(const godot::String &key, const godot::String &field);
    godot::Array hkeys(const godot::String &key);
    godot::Array hvals(const godot::String &key);
    int64_t hlen(const godot::String &key);

    // List commands
    int64_t lpush(const godot::String &key, const godot::Variant &values);
    int64_t rpush(const godot::String &key, const godot::Variant &values);
    godot::Variant lpop(const godot::String &key);
    godot::Variant rpop(const godot::String &key);
    int64_t llen(const godot::String &key);
    godot::Array lrange(const godot::String &key, int64_t start, int64_t stop);
    godot::Variant lindex(const godot::String &key, int64_t index);
    bool lset(const godot::String &key, int64_t index, const godot::Variant &value);
    int64_t lrem(const godot::String &key, int64_t count, const godot::Variant &value);

    // Set commands
    int64_t sadd(const godot::String &key, const godot::Variant &members);
    int64_t srem(const godot::String &key, const godot::Variant &members);
    godot::Array smembers(const godot::String &key);
    bool sismember(const godot::String &key, const godot::Variant &member);
    int64_t scard(const godot::String &key);
    godot::Variant spop(const godot::String &key);
    bool smove(const godot::String &source, const godot::String &destination, const godot::Variant &member);

    // Pub/Sub commands
    void subscribe(const godot::String &channel, godot::Object *subscriber);
    void unsubscribe(const godot::String &channel, godot::Object *subscriber);
    void psubscribe(const godot::String &pattern, godot::Object *subscriber);
    void punsubscribe(const godot::String &pattern, godot::Object *subscriber);
    std::vector<godot::Object*> get_subscribers(const godot::String &channel);
    std::unordered_map<std::string, std::vector<godot::Object*>> get_psubscribers();
};

#endif // GEDIS_STORE_H