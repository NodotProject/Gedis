#include "gedis.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <regex>

using namespace godot;

// Static instance registry
std::set<Gedis*> Gedis::instances;
std::map<Gedis*, int> Gedis::instance_ids;
int Gedis::next_instance_id = 0;
bool Gedis::debugger_registered = false;

void Gedis::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set", "key", "value"), &Gedis::set);
    ClassDB::bind_method(D_METHOD("get", "key"), &Gedis::get);
    ClassDB::bind_method(D_METHOD("del", "keys"), &Gedis::del);
    ClassDB::bind_method(D_METHOD("exists", "keys"), &Gedis::exists);
    ClassDB::bind_method(D_METHOD("key_exists", "key"), &Gedis::key_exists);
    ClassDB::bind_method(D_METHOD("incr", "key"), &Gedis::incr);
    ClassDB::bind_method(D_METHOD("decr", "key"), &Gedis::decr);
    ClassDB::bind_method(D_METHOD("keys", "pattern"), &Gedis::keys);
    ClassDB::bind_method(D_METHOD("mset", "dictionary"), &Gedis::mset);
    ClassDB::bind_method(D_METHOD("mget", "keys"), &Gedis::mget);

    // Debugger commands
    ClassDB::bind_method(D_METHOD("type", "key"), &Gedis::type);
    ClassDB::bind_method(D_METHOD("dump", "key"), &Gedis::dump);
    ClassDB::bind_method(D_METHOD("snapshot", "pattern"), &Gedis::snapshot, DEFVAL("*"));

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

    // Instance management
    ClassDB::bind_method(D_METHOD("set_instance_name", "name"), &Gedis::set_instance_name);
    ClassDB::bind_method(D_METHOD("get_instance_name"), &Gedis::get_instance_name);
    ClassDB::bind_static_method("Gedis", D_METHOD("get_all_instances"), &Gedis::get_all_instances);

    ADD_SIGNAL(MethodInfo("pubsub_message", PropertyInfo(Variant::STRING, "channel"), PropertyInfo(Variant::NIL, "message")));
    ADD_SIGNAL(MethodInfo("psub_message", PropertyInfo(Variant::STRING, "pattern"), PropertyInfo(Variant::STRING, "channel"), PropertyInfo(Variant::NIL, "message")));
}

Gedis::Gedis() {
    // Register debugger on first instance creation
    if (!debugger_registered) {
        debugger_registered = _register_debugger();
    }
    
    // Add to instance registry
    instances.insert(this);
    instance_id = next_instance_id++;
    instance_ids[this] = instance_id;
    instance_name = "Gedis_" + String::num_int64(instance_id);
    
    // Notify debugger of new instance
    if (debugger_registered) {
        _send_instances_update();
    }
}

Gedis::~Gedis() {
    instances.erase(this);
    instance_ids.erase(this);
    
    // Notify debugger of instance removal
    if (debugger_registered) {
        _send_instances_update();
    }
}

void Gedis::set_instance_name(const String &name) {
    instance_name = name;
}

String Gedis::get_instance_name() const {
    return instance_name;
}

Array Gedis::get_all_instances() {
    Array result;
    for (Gedis* instance : instances) {
        if (instance) {
            Dictionary instance_info;
            instance_info["id"] = instance_ids[instance];
            instance_info["name"] = instance->get_instance_name();
            instance_info["object"] = instance;
            result.push_back(instance_info);
        }
    }
    return result;
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

void Gedis::mset(const Dictionary &dictionary) {
    store.mset(dictionary);
}

Array Gedis::mget(const Array &keys) {
    return store.mget(keys);
}

// Debugger commands
String Gedis::type(const String &key) {
    return store.type(key);
}

Dictionary Gedis::dump(const String &key) {
    return store.dump(key);
}

Dictionary Gedis::snapshot(const String &pattern) {
    return store.snapshot(pattern);
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
        if (channel.match(godot::String(pattern.c_str()))) {
            for (Object *subscriber : subscribers) {
                subscriber->emit_signal("psub_message", godot::String(pattern.c_str()), channel, message);
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

// Debugger communication methods
bool Gedis::_register_debugger() {
    EngineDebugger *debugger = EngineDebugger::get_singleton();
    if (!debugger || !debugger->is_active()) {
        return false;
    }

    // Register the main capture used by the plugin front-end
    debugger->register_message_capture("gedis", callable_mp_static(&Gedis::_capture_debugger_message));

    // Also register handlers for messages that may be sent without the 'gedis' prefix
    // (some frontend code may call session.send_message with plain names).
    debugger->register_message_capture("request_instances", callable_mp_static(&Gedis::_capture_debugger_message));
    debugger->register_message_capture("request_instance_data", callable_mp_static(&Gedis::_capture_debugger_message));

    debugger->register_message_capture("", callable_mp_static(&Gedis::_debug_all_messages));
    return true;
}

bool Gedis::_debug_all_messages(const String &message, const Array &data) {
    return false; // Do not consume the message.
}

bool Gedis::_capture_debugger_message(const String &message, const Array &data) {
    EngineDebugger *debugger = EngineDebugger::get_singleton();
    if (!debugger) {
        return false;
    }

    // Support two shapes: direct message names (e.g. "request_instance_data")
    // and wrapped messages sent on the "gedis" channel where the first
    // element of data is the actual sub-command (e.g. ["request_instance_data", ...]).
    String effective_message = message;
    Array effective_data = data;

    if (message == "gedis" && data.size() > 0) {
        // Expect the first element to be the sub-command name
        if (data[0].get_type() == Variant::STRING) {
            effective_message = String(data[0]);
            // Build effective_data = data.slice(1..end)
            effective_data = Array();
            for (int i = 1; i < data.size(); i++) {
                effective_data.push_back(data[i]);
            }
        }
    }

    // Requesting the list of instances
    if (effective_message == "request_instances") {
        _send_instances_update();
        return true;
    }

    // Request data from a specific instance via the debugger plugin.
    // Expected data format:
    //   [ id (int), command-specific params... ]
    // Supported commands: "dump", "snapshot", "keys", "type", "get"
    if (effective_message == "request_instance_data") {

        if (effective_data.size() < 1) {
            // Invalid payload
            Array resp;
            resp.push_back(Variant()); // id unknown
            Dictionary err;
            err["error"] = "invalid_payload";
            resp.push_back(err);
            debugger->send_message("gedis:instance_response", resp);
            return true;
        }

        int id = 0;
        // Extract id (be defensive: could be int or Variant convertible)
        if (effective_data[0].get_type() == Variant::INT) {
            id = (int)effective_data[0];
        } else {
            id = (int)Variant(effective_data[0]);
        }

        String command;
        String param;
        if (effective_data.size() > 1 && effective_data[1].get_type() == Variant::STRING) {
            command = String(effective_data[1]);
        } else if (effective_data.size() > 1) {
            // If command passed as Variant convertible to String
            command = String(effective_data[1]);
        }

        if (effective_data.size() > 2) {
            param = String(effective_data[2]);
        }


        Gedis *instance = _get_instance_by_id(id);
        Array resp;
        resp.push_back(id);

        if (!instance) {
            Dictionary err;
            err["error"] = "instance_not_found";
            resp.push_back(err);
            debugger->send_message("gedis:instance_response", resp);
            return true;
        }

        // Execute the requested command on the instance and return the result.
        if (command == "dump") {
            Variant result = instance->dump(param);
            resp.push_back(command);
            resp.push_back(result);
        } else if (command == "snapshot") {
            Variant result = instance->snapshot(param);
            resp.push_back(command);
            resp.push_back(result);
        } else if (command == "set") {
            if (effective_data.size() > 3) {
                String key_to_set = String(effective_data[2]);
                Variant value_to_set = effective_data[3];
                instance->set(key_to_set, value_to_set);
                resp.push_back(command);
                resp.push_back(true); // Indicate success
            } else {
                // Handle error: not enough parameters
                Dictionary err;
                err["error"] = "invalid_payload_set";
                resp.push_back(command);
                resp.push_back(err);
            }
        } else if (command == "keys") {
            Variant result = instance->keys(param);
            resp.push_back(command);
            resp.push_back(result);
        } else if (command == "type") {
            Variant result = instance->type(param);
            resp.push_back(command);
            resp.push_back(result);
        } else if (command == "get") {
            Variant result = instance->get(param);
            resp.push_back(command);
            resp.push_back(result);
        } else {
            Dictionary err;
            err["error"] = "unknown_command";
            err["command"] = command;
            resp.push_back(command);
            resp.push_back(err);
        }

        debugger->send_message("gedis:instance_response", resp);
        return true;
    }

    return false;
}

void Gedis::_send_instances_update() {
    EngineDebugger *debugger = EngineDebugger::get_singleton();
    if (!debugger || !debugger->is_active()) {
        return;
    }
    
    Array instances_data;
    for (Gedis* instance : instances) {
        if (instance && Object::cast_to<Object>(instance)) {
            Dictionary instance_info;
            instance_info["id"] = instance_ids[instance];
            instance_info["name"] = instance->get_instance_name();
            // Expose the actual Gedis Object to the debugger frontend so the plugin
            // can query it directly without relying on id lookups.
            instance_info["object"] = instance;
            instances_data.push_back(instance_info);
        }
    }
    
    debugger->send_message("gedis:instances_update", instances_data);
}

Gedis* Gedis::_get_instance_by_id(int id) {
    for (auto const& [instance, instance_id] : instance_ids) {
        if (instance_id == id) {
            return instance;
        }
    }
    return nullptr;
}