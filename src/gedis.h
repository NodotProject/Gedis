#ifndef GEDIS_H
#define GEDIS_H

#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <set>
#include <map>
#include "gedis_store.h"

#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <chrono>

namespace godot {

class Gedis : public Object {
    GDCLASS(Gedis, Object)

private:
    GedisStore store;
    static std::set<Gedis*> instances;
    static std::map<Gedis*, int> instance_ids;
    static int next_instance_id;
    static bool debugger_registered;
    String instance_name;
    int instance_id;

    // Background worker for expiry/persistence
    std::thread worker_thread;
    std::atomic<bool> worker_running{false};
    std::mutex store_mutex; // minimal locking to protect store during background ops
    std::condition_variable worker_cv;
    std::chrono::milliseconds worker_interval{std::chrono::milliseconds(250)}; // default 250ms

    // Debugger communication
    static bool _register_debugger();
    static bool _capture_debugger_message(const String &message, const Array &data);
    static void _send_instances_update();
    static Gedis* _get_instance_by_id(int id);
    static bool _debug_all_messages(const String &message, const Array &data);

    // Worker control
    void start_worker();
    void stop_worker();
    void worker_loop();
    
public:
    static Gedis* get_instance_by_id(int id);

protected:
    static void _bind_methods();

public:
    Gedis();
    ~Gedis();

    // Instance management
    void set_instance_name(const String &name);
    String get_instance_name() const;
    static Array get_all_instances();

    void set(const String &key, const Variant &value);
    Variant get(const String &key);
    int64_t del(const Array &keys);
    int64_t exists(const Array &keys);
    bool key_exists(const String &key);
    Variant incr(const String &key);
    Variant decr(const String &key);
    TypedArray<String> keys(const String &pattern);
    void mset(const Dictionary &dictionary);
    Array mget(const Array &keys);

    // Debugger commands
    String type(const String &key);
    Dictionary dump(const String &key);
    Dictionary snapshot(const String &pattern);

    // Expiry commands
    bool expire(const String &key, int64_t seconds);
    int64_t ttl(const String &key);
    bool persist(const String &key);

    // Hash commands
    int64_t hset(const String &key, const String &field, const Variant &value);
    Variant hget(const String &key, const String &field, const Variant &default_value = Variant());
    Dictionary hgetall(const String &key);
    int64_t hdel(const String &key, const Variant &fields);
    bool hexists(const String &key, const String &field);
    Array hkeys(const String &key);
    Array hvals(const String &key);
    int64_t hlen(const String &key);

    // List commands
    int64_t lpush(const String &key, const Variant &values);
    int64_t rpush(const String &key, const Variant &values);
    Variant lpop(const String &key);
    Variant rpop(const String &key);
    int64_t llen(const String &key);
    Array lrange(const String &key, int64_t start, int64_t stop);
    Variant lindex(const String &key, int64_t index);
    bool lset(const String &key, int64_t index, const Variant &value);
    int64_t lrem(const String &key, int64_t count, const Variant &value);

    // Set commands
    int64_t sadd(const String &key, const Variant &members);
    int64_t srem(const String &key, const Variant &members);
    Array smembers(const String &key);
    bool sismember(const String &key, const Variant &member);
    int64_t scard(const String &key);
    Variant spop(const String &key);
    bool smove(const String &source, const String &destination, const Variant &member);

    // Pub/Sub commands
    void publish(const String &channel, const Variant &message);
    void subscribe(const String &channel, Object *subscriber);
    void unsubscribe(const String &channel, Object *subscriber);
    void psubscribe(const String &pattern, Object *subscriber);
    void punsubscribe(const String &pattern, Object *subscriber);
};

}

#endif // GEDIS_H