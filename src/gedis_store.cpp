#include "gedis_store.h"
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <regex>

GedisStore::GedisStore() {
    object_pool.resize(GEDIS_OBJECT_POOL_SIZE);
    for (int i = 0; i < GEDIS_OBJECT_POOL_SIZE; ++i) {
        free_list.push_back(i);
    }
}

GedisStore::~GedisStore() {
    // Destructor - no need to delete objects, they are in the pool
    store.clear();
}

void GedisStore::set(const godot::String& key, const godot::Variant& value) {
    std::string std_key = key.utf8().get_data();
    // If key exists, deallocate old object before replacing
    if (store.count(std_key)) {
        _deallocate_object(store[std_key]);
    }
    
    // Create a new GedisObject based on the variant type
    GedisObject* obj = nullptr;
    switch (value.get_type()) {
        case godot::Variant::STRING: {
            std::string* str_data = new std::string(godot::String(value).utf8().get_data());
            obj = _allocate_object(STRING, str_data);
            break;
        }
        default: {
            // For now, convert everything else to string
            std::string* str_data = new std::string(godot::String(value).utf8().get_data());
            obj = _allocate_object(STRING, str_data);
            break;
        }
    }
    
    store[std_key] = obj;
}

godot::Variant GedisStore::get(const godot::String& key) {
    get_call_count++;
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        // Probabilistic expiry check
        if (get_call_count % 100 == 0 && obj->expiration != -1 && obj->expiration <= time(0)) {
            _deallocate_object(obj);
            store.erase(std_key);
            return godot::Variant(); // Key expired, return null
        }
        if (obj && obj->type == STRING && obj->data) {
            std::string* str_data = static_cast<std::string*>(obj->data);
            return godot::String(str_data->c_str());
        }
    }
    return godot::Variant(); // Return null variant if not found
}

int64_t GedisStore::del(const godot::Array& keys) {
    int64_t deleted_count = 0;
    for (int i = 0; i < keys.size(); i++) {
        std::string std_key = godot::String(keys[i]).utf8().get_data();
        if (store.count(std_key)) {
            _deallocate_object(store[std_key]);
            store.erase(std_key);
            deleted_count++;
        }
    }
    return deleted_count;
}

int64_t GedisStore::exists(const godot::Array& keys) {
    int64_t exists_count = 0;
    for (int i = 0; i < keys.size(); i++) {
        std::string std_key = godot::String(keys[i]).utf8().get_data();
        if (store.count(std_key)) {
            exists_count++;
        }
    }
    return exists_count;
}

bool GedisStore::exists(const godot::String& key) {
    get_call_count++;
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        // Probabilistic expiry check
        if (get_call_count % 100 == 0 && obj->expiration != -1 && obj->expiration <= time(0)) {
            _deallocate_object(obj);
            store.erase(std_key);
            return false; // Key expired
        }
        return true;
    }
    return false;
}

godot::Variant GedisStore::incr(const godot::String& key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        if (obj && obj->type == STRING && obj->data) {
            std::string* str_data = static_cast<std::string*>(obj->data);
            try {
                int64_t value = std::stoll(*str_data);
                value++;
                *str_data = std::to_string(value);
                return godot::Variant(value);
            } catch (const std::invalid_argument& ia) {
                return godot::Variant();
            } catch (const std::out_of_range& oor) {
                return godot::Variant();
            }
        }
    } else {
        // Key doesn't exist, create it with value 1
        std::string* str_data = new std::string("1");
        GedisObject* obj = _allocate_object(STRING, str_data);
        store[std_key] = obj;
        return godot::Variant(1);
    }
    
    return godot::Variant();
}

godot::Variant GedisStore::decr(const godot::String& key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        if (obj && obj->type == STRING && obj->data) {
            std::string* str_data = static_cast<std::string*>(obj->data);
            try {
                int64_t value = std::stoll(*str_data);
                value--;
                *str_data = std::to_string(value);
                return godot::Variant(value);
            } catch (const std::invalid_argument& ia) {
                return godot::Variant();
            } catch (const std::out_of_range& oor) {
                return godot::Variant();
            }
        }
    } else {
        // Key doesn't exist, create it with value -1
        std::string* str_data = new std::string("-1");
        GedisObject* obj = _allocate_object(STRING, str_data);
        store[std_key] = obj;
        return godot::Variant(-1);
    }
    
    return godot::Variant();
}

godot::TypedArray<godot::String> GedisStore::keys(const godot::String& pattern) {
    godot::TypedArray<godot::String> result;
    int64_t now = time(0);
    std::string std_pattern = pattern.utf8().get_data();
    std::regex regex_pattern(std_pattern);
    
    for (auto it = store.begin(); it != store.end();) {
        // Check if key has expired
        if (it->second->expiration != -1 && it->second->expiration <= now) {
            _deallocate_object(it->second);
            it = store.erase(it);
            continue;
        }
        
        if (std::regex_match(it->first, regex_pattern)) {
            result.append(godot::String(it->first.c_str()));
        }
        ++it;
    }
    
    return result;
}

void GedisStore::mset(const godot::Dictionary& dictionary) {
    godot::Array keys = dictionary.keys();
    for (int i = 0; i < keys.size(); i++) {
        godot::String key = keys[i];
        set(key, dictionary[key]);
    }
}

godot::Array GedisStore::mget(const godot::Array& keys) {
    godot::Array result;
    for (int i = 0; i < keys.size(); i++) {
        result.push_back(get(keys[i]));
    }
    return result;
}

void GedisStore::remove_expired_keys() {
    int64_t now = time(0);
    for (auto it = store.begin(); it != store.end();) {
        if (it->second->expiration != -1 && it->second->expiration <= now) {
            _deallocate_object(it->second);
            it = store.erase(it);
        } else {
            ++it;
        }
    }
}

// Debugger commands
godot::String GedisStore::type(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        if (obj->expiration != -1 && obj->expiration <= time(0)) {
            _deallocate_object(obj);
            store.erase(std_key);
            return "NONE";
        }
        switch (obj->type) {
            case STRING: return "STRING";
            case LIST: return "LIST";
            case HASH: return "HASH";
            case SET: return "SET";
        }
    }
    return "NONE";
}

godot::Dictionary GedisStore::dump(const godot::String &key) {
    godot::Dictionary result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        if (obj->expiration != -1 && obj->expiration <= time(0)) {
            _deallocate_object(obj);
            store.erase(std_key);
            result["type"] = "NONE";
            result["ttl"] = -2;
            result["value"] = godot::Variant();
            return result;
        }

        result["type"] = type(key);
        result["ttl"] = ttl(key);

        switch (obj->type) {
            case STRING:
                result["value"] = get(key);
                break;
            case LIST:
                result["value"] = lrange(key, 0, -1);
                break;
            case HASH:
                result["value"] = hgetall(key);
                break;
            case SET:
                result["value"] = smembers(key);
                break;
        }
    } else {
        result["type"] = "NONE";
        result["ttl"] = -2;
        result["value"] = godot::Variant();
    }

    return result;
}

godot::Dictionary GedisStore::snapshot(const godot::String &pattern) {
    godot::Dictionary result;
    godot::TypedArray<godot::String> matching_keys = keys(pattern);

    for (int i = 0; i < matching_keys.size(); i++) {
        godot::String key = matching_keys[i];
        godot::Dictionary key_info;
        key_info["type"] = type(key);
        key_info["ttl"] = ttl(key);
        result[key] = key_info;
    }

    return result;
}

// Expiry commands
bool GedisStore::expire(const godot::String &key, int64_t seconds) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        store[std_key]->expiration = time(0) + seconds;
        return true;
    }
    return false;
}

int64_t GedisStore::ttl(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        if (obj->expiration == -1) {
            return -1;
        }
        int64_t remaining = obj->expiration - time(0);
        return (remaining > 0) ? remaining : -2;
    }
    return -2;
}

bool GedisStore::persist(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        if (obj->expiration == -1) {
            // Key doesn't have an expiry, return false
            return false;
        }
        // Key has an expiry, remove it and return true
        obj->expiration = -1;
        return true;
    }
    return false;
}

// Hash commands
int64_t GedisStore::hset(const godot::String &key, const godot::String &field, const godot::Variant &value) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key) && store[std_key]->type != HASH) {
        return -1; // Wrong type
    }

    if (!store.count(std_key)) {
        store[std_key] = _allocate_object(HASH, new std::unordered_map<std::string, std::string>());
    }

    auto* hash = store[std_key]->getHash();
    std::string std_field = field.utf8().get_data();
    int64_t created = !hash->count(std_field);
    (*hash)[std_field] = godot::String(value).utf8().get_data();
    return created;
}

godot::Variant GedisStore::hget(const godot::String &key, const godot::String &field, const godot::Variant &default_value) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != HASH) {
        return default_value;
    }

    auto* hash = store[std_key]->getHash();
    std::string std_field = field.utf8().get_data();
    if (hash->count(std_field)) {
        return godot::String(hash->at(std_field).c_str());
    }

    return default_value;
}

godot::Dictionary GedisStore::hgetall(const godot::String &key) {
    godot::Dictionary result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key) && store[std_key]->type == HASH) {
        auto* hash = store[std_key]->getHash();
        for (const auto& [field, value] : *hash) {
            result[godot::String(field.c_str())] = godot::String(value.c_str());
        }
    }

    return result;
}

int64_t GedisStore::hdel(const godot::String &key, const godot::Variant &fields) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != HASH) {
        return 0;
    }

    int64_t deleted_count = 0;
    auto* hash = store[std_key]->getHash();
    
    // Handle both single field (String) and multiple fields (Array)
    if (fields.get_type() == godot::Variant::ARRAY) {
        godot::Array field_array = fields;
        for (int i = 0; i < field_array.size(); i++) {
            if (hash->erase(godot::String(field_array[i]).utf8().get_data())) {
                deleted_count++;
            }
        }
    } else {
        // Single field
        if (hash->erase(godot::String(fields).utf8().get_data())) {
            deleted_count++;
        }
    }
    
    return deleted_count;
}

bool GedisStore::hexists(const godot::String &key, const godot::String &field) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != HASH) {
        return false;
    }

    auto* hash = store[std_key]->getHash();
    return hash->count(field.utf8().get_data());
}

godot::Array GedisStore::hkeys(const godot::String &key) {
    godot::Array result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key) && store[std_key]->type == HASH) {
        auto* hash = store[std_key]->getHash();
        for (const auto& [field, value] : *hash) {
            result.append(godot::String(field.c_str()));
        }
    }

    return result;
}

godot::Array GedisStore::hvals(const godot::String &key) {
    godot::Array result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key) && store[std_key]->type == HASH) {
        auto* hash = store[std_key]->getHash();
        for (const auto& [field, value] : *hash) {
            result.append(godot::String(value.c_str()));
        }
    }

    return result;
}

int64_t GedisStore::hlen(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != HASH) {
        return 0;
    }
    return store[std_key]->getHash()->size();
}

// List commands
int64_t GedisStore::lpush(const godot::String &key, const godot::Variant &values) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key) && store[std_key]->type != LIST) {
        return -1; // Wrong type
    }

    if (!store.count(std_key)) {
        store[std_key] = _allocate_object(LIST, new std::vector<std::string>());
    }

    auto* list = store[std_key]->getList();
    
    // Handle both single value and array of values
    if (values.get_type() == godot::Variant::ARRAY) {
        godot::Array value_array = values;
        for (int i = 0; i < value_array.size(); i++) {
            list->insert(list->begin(), godot::String(value_array[i]).utf8().get_data());
        }
    } else {
        // Single value
        list->insert(list->begin(), godot::String(values).utf8().get_data());
    }

    return list->size();
}

int64_t GedisStore::rpush(const godot::String &key, const godot::Variant &values) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key) && store[std_key]->type != LIST) {
        return -1; // Wrong type
    }

    if (!store.count(std_key)) {
        store[std_key] = _allocate_object(LIST, new std::vector<std::string>());
    }

    auto* list = store[std_key]->getList();
    
    // Handle both single value and array of values
    if (values.get_type() == godot::Variant::ARRAY) {
        godot::Array value_array = values;
        for (int i = 0; i < value_array.size(); i++) {
            list->push_back(godot::String(value_array[i]).utf8().get_data());
        }
    } else {
        // Single value
        list->push_back(godot::String(values).utf8().get_data());
    }

    return list->size();
}

godot::Variant GedisStore::lpop(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != LIST) {
        return godot::Variant();
    }

    auto* list = store[std_key]->getList();
    if (list->empty()) {
        return godot::Variant();
    }

    std::string value = list->front();
    list->erase(list->begin());
    return godot::String(value.c_str());
}

godot::Variant GedisStore::rpop(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != LIST) {
        return godot::Variant();
    }

    auto* list = store[std_key]->getList();
    if (list->empty()) {
        return godot::Variant();
    }

    std::string value = list->back();
    list->pop_back();
    return godot::String(value.c_str());
}

int64_t GedisStore::llen(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != LIST) {
        return 0;
    }
    return store[std_key]->getList()->size();
}

godot::Array GedisStore::lrange(const godot::String &key, int64_t start, int64_t stop) {
    godot::Array result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key) && store[std_key]->type == LIST) {
        auto* list = store[std_key]->getList();
        int64_t len = list->size();
        if (start < 0) start = len + start;
        if (stop < 0) stop = len + stop;
        if (start < 0) start = 0;
        if (stop >= len) stop = len - 1;

        if (start <= stop) {
            for (int64_t i = start; i <= stop; i++) {
                result.append(godot::String((*list)[i].c_str()));
            }
        }
    }

    return result;
}

godot::Variant GedisStore::lindex(const godot::String &key, int64_t index) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != LIST) {
        return godot::Variant();
    }

    auto* list = store[std_key]->getList();
    if (index < 0) index = list->size() + index;
    if (index < 0 || index >= (int64_t)list->size()) {
        return godot::Variant();
    }

    return godot::String((*list)[index].c_str());
}

bool GedisStore::lset(const godot::String &key, int64_t index, const godot::Variant &value) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != LIST) {
        return false;
    }

    auto* list = store[std_key]->getList();
    if (index < 0) index = list->size() + index;
    if (index < 0 || index >= (int64_t)list->size()) {
        return false;
    }

    (*list)[index] = godot::String(value).utf8().get_data();
    return true;
}

int64_t GedisStore::lrem(const godot::String &key, int64_t count, const godot::Variant &value) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != LIST) {
        return 0;
    }

    auto* list = store[std_key]->getList();
    std::string target_value = godot::String(value).utf8().get_data();
    int64_t removed_count = 0;

    if (count == 0) {
        // Remove all occurrences
        auto original_size = list->size();
        list->erase(std::remove(list->begin(), list->end(), target_value), list->end());
        removed_count = original_size - list->size();
    } else if (count > 0) {
        // Remove first count occurrences
        auto it = list->begin();
        while (it != list->end() && removed_count < count) {
            if (*it == target_value) {
                it = list->erase(it);
                removed_count++;
            } else {
                ++it;
            }
        }
    } else {
        // Remove last |count| occurrences
        count = -count;
        auto it = list->rbegin();
        while (it != list->rend() && removed_count < count) {
            if (*it == target_value) {
                it = std::reverse_iterator(list->erase(std::next(it).base()));
                removed_count++;
            } else {
                ++it;
            }
        }
    }

    return removed_count;
}

// Set commands
int64_t GedisStore::sadd(const godot::String &key, const godot::Variant &members) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key) && store[std_key]->type != SET) {
        return -1; // Wrong type
    }

    if (!store.count(std_key)) {
        store[std_key] = _allocate_object(SET, new std::unordered_set<std::string>());
    }

    int64_t added_count = 0;
    auto* set = store[std_key]->getSet();
    
    // Handle both single member and array of members
    if (members.get_type() == godot::Variant::ARRAY) {
        godot::Array member_array = members;
        for (int i = 0; i < member_array.size(); i++) {
            if (set->insert(godot::String(member_array[i]).utf8().get_data()).second) {
                added_count++;
            }
        }
    } else {
        // Single member
        if (set->insert(godot::String(members).utf8().get_data()).second) {
            added_count++;
        }
    }

    return added_count;
}

int64_t GedisStore::srem(const godot::String &key, const godot::Variant &members) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != SET) {
        return 0;
    }

    int64_t removed_count = 0;
    auto* set = store[std_key]->getSet();
    
    // Handle both single member and array of members
    if (members.get_type() == godot::Variant::ARRAY) {
        godot::Array member_array = members;
        for (int i = 0; i < member_array.size(); i++) {
            if (set->erase(godot::String(member_array[i]).utf8().get_data())) {
                removed_count++;
            }
        }
    } else {
        // Single member
        if (set->erase(godot::String(members).utf8().get_data())) {
            removed_count++;
        }
    }

    return removed_count;
}

godot::Array GedisStore::smembers(const godot::String &key) {
    godot::Array result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key) && store[std_key]->type == SET) {
        auto* set = store[std_key]->getSet();
        for (const auto& member : *set) {
            result.append(godot::String(member.c_str()));
        }
    }

    return result;
}

bool GedisStore::sismember(const godot::String &key, const godot::Variant &member) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != SET) {
        return false;
    }

    auto* set = store[std_key]->getSet();
    return set->count(godot::String(member).utf8().get_data());
}

int64_t GedisStore::scard(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != SET) {
        return 0;
    }
    return store[std_key]->getSet()->size();
}

godot::Variant GedisStore::spop(const godot::String &key) {
    std::string std_key = key.utf8().get_data();
    if (!store.count(std_key) || store[std_key]->type != SET) {
        return godot::Variant();
    }

    auto* set = store[std_key]->getSet();
    if (set->empty()) {
        return godot::Variant();
    }

    // Get a random element (first one for simplicity)
    auto it = set->begin();
    std::string value = *it;
    set->erase(it);
    return godot::String(value.c_str());
}

bool GedisStore::smove(const godot::String &source, const godot::String &destination, const godot::Variant &member) {
    std::string std_source = source.utf8().get_data();
    std::string std_destination = destination.utf8().get_data();
    std::string std_member = godot::String(member).utf8().get_data();

    if (!store.count(std_source) || store[std_source]->type != SET) {
        return false;
    }

    auto* source_set = store[std_source]->getSet();
    if (!source_set->count(std_member)) {
        return false;
    }

    // Create destination set if it doesn't exist
    if (!store.count(std_destination)) {
        store[std_destination] = _allocate_object(SET, new std::unordered_set<std::string>());
    } else if (store[std_destination]->type != SET) {
        return false;
    }

    auto* dest_set = store[std_destination]->getSet();
    
    // Move the member
    source_set->erase(std_member);
    dest_set->insert(std_member);
    
    return true;
}

// Pub/Sub commands
void GedisStore::subscribe(const godot::String &channel, godot::Object *subscriber) {
    subscriptions[channel.utf8().get_data()].push_back(subscriber);
}

void GedisStore::unsubscribe(const godot::String &channel, godot::Object *subscriber) {
    std::string std_channel = channel.utf8().get_data();
    if (subscriptions.count(std_channel)) {
        auto& subscribers = subscriptions[std_channel];
        subscribers.erase(std::remove(subscribers.begin(), subscribers.end(), subscriber), subscribers.end());
    }
}

void GedisStore::psubscribe(const godot::String &pattern, godot::Object *subscriber) {
    psubscriptions[pattern.utf8().get_data()].push_back(subscriber);
}

void GedisStore::punsubscribe(const godot::String &pattern, godot::Object *subscriber) {
    std::string std_pattern = pattern.utf8().get_data();
    if (psubscriptions.count(std_pattern)) {
        auto& subscribers = psubscriptions[std_pattern];
        subscribers.erase(std::remove(subscribers.begin(), subscribers.end(), subscriber), subscribers.end());
    }
}

std::vector<godot::Object*> GedisStore::get_subscribers(const godot::String &channel) {
    std::string std_channel = channel.utf8().get_data();
    if (subscriptions.count(std_channel)) {
        return subscriptions[std_channel];
    }
    return {};
}

std::unordered_map<std::string, std::vector<godot::Object*>> GedisStore::get_psubscribers() {
    return psubscriptions;
}

GedisObject* GedisStore::_allocate_object(GedisObjectType t, void* d) {
    if (free_list.empty()) {
        // Pool is full, fallback to new
        return new GedisObject(t, d);
    }
    int index = free_list.back();
    free_list.pop_back();
    GedisObject* obj = &object_pool[index];
    obj->type = t;
    obj->data = d;
    obj->expiration = -1;
    return obj;
}

void GedisStore::_deallocate_object(GedisObject* obj) {
    if (obj >= &object_pool[0] && obj <= &object_pool[GEDIS_OBJECT_POOL_SIZE - 1]) {
        int index = obj - &object_pool[0];
        free_list.push_back(index);
    } else {
        // This object was not from the pool, so delete it
        delete obj;
    }
}