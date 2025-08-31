#include "gedis_store.h"
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <string>
#include <regex>

GedisStore::GedisStore() {
    // Constructor
}

GedisStore::~GedisStore() {
    // Destructor - clean up all GedisObject pointers
    for (auto const& [key, val] : store) {
        delete val;
    }
    store.clear();
}

void GedisStore::set(const godot::String& key, const godot::Variant& value) {
    std::string std_key = key.utf8().get_data();
    
    // If key exists, delete old object before replacing
    if (store.count(std_key)) {
        delete store[std_key];
    }
    
    // Create a new GedisObject based on the variant type
    GedisObject* obj = nullptr;
    switch (value.get_type()) {
        case godot::Variant::STRING: {
            std::string* str_data = new std::string(godot::String(value).utf8().get_data());
            obj = new GedisObject(STRING, str_data);
            break;
        }
        default: {
            // For now, convert everything else to string
            std::string* str_data = new std::string(godot::String(value).utf8().get_data());
            obj = new GedisObject(STRING, str_data);
            break;
        }
    }
    
    store[std_key] = obj;
}

godot::Variant GedisStore::get(const godot::String& key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        // Check if key has expired
        if (obj->expiration != -1 && obj->expiration <= time(0)) {
            delete obj;
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
        godot::String key = keys[i];
        std::string std_key = key.utf8().get_data();
        if (store.count(std_key)) {
            delete store[std_key];
            store.erase(std_key);
            deleted_count++;
        }
    }
    return deleted_count;
}

int64_t GedisStore::exists(const godot::Array& keys) {
    int64_t exists_count = 0;
    for (int i = 0; i < keys.size(); i++) {
        godot::String key = keys[i];
        std::string std_key = key.utf8().get_data();
        if (store.count(std_key)) {
            exists_count++;
        }
    }
    return exists_count;
}

bool GedisStore::exists(const godot::String& key) {
    std::string std_key = key.utf8().get_data();
    if (store.count(std_key)) {
        GedisObject* obj = store[std_key];
        // Check if key has expired
        if (obj->expiration != -1 && obj->expiration <= time(0)) {
            delete obj;
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
            } catch (...) {
                // If conversion fails, return error
                return godot::Variant();
            }
        }
    } else {
        // Key doesn't exist, create it with value 1
        std::string* str_data = new std::string("1");
        GedisObject* obj = new GedisObject(STRING, str_data);
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
            } catch (...) {
                // If conversion fails, return error
                return godot::Variant();
            }
        }
    } else {
        // Key doesn't exist, create it with value -1
        std::string* str_data = new std::string("-1");
        GedisObject* obj = new GedisObject(STRING, str_data);
        store[std_key] = obj;
        return godot::Variant(-1);
    }
    
    return godot::Variant();
}

godot::TypedArray<godot::String> GedisStore::keys(const godot::String& pattern) {
    godot::TypedArray<godot::String> result;
    std::string pattern_str = pattern.utf8().get_data();
    
    // Convert glob pattern to regex
    std::string regex_pattern = "";
    for (char c : pattern_str) {
        switch (c) {
            case '*':
                regex_pattern += ".*";
                break;
            case '?':
                regex_pattern += ".";
                break;
            case '.':
            case '^':
            case '$':
            case '+':
            case '(':
            case ')':
            case '[':
            case ']':
            case '{':
            case '}':
            case '|':
            case '\\':
                regex_pattern += "\\";
                regex_pattern += c;
                break;
            default:
                regex_pattern += c;
                break;
        }
    }
    
    try {
        std::regex pattern_regex("^" + regex_pattern + "$");
        for (const auto& [key, val] : store) {
            if (std::regex_match(key, pattern_regex)) {
                result.append(godot::String(key.c_str()));
            }
        }
    } catch (const std::regex_error& e) {
        // If regex fails, fall back to exact match
        for (const auto& [key, val] : store) {
            if (key == pattern_str) {
                result.append(godot::String(key.c_str()));
            }
        }
    }
    
    return result;
}

void GedisStore::remove_expired_keys() {
    int64_t now = time(0);
    for (auto it = store.begin(); it != store.end();) {
        if (it->second->expiration != -1 && it->second->expiration <= now) {
            delete it->second;
            it = store.erase(it);
        } else {
            ++it;
        }
    }
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
    std::string std_field = field.utf8().get_data();
    std::string std_value = godot::String(value).utf8().get_data();

    if (store.count(std_key) && store[std_key]->type != HASH) {
        return -1; // Wrong type
    }

    if (!store.count(std_key)) {
        store[std_key] = new GedisObject(HASH, new std::unordered_map<std::string, std::string>());
    }

    auto* hash = store[std_key]->getHash();
    int64_t created = !hash->count(std_field);
    (*hash)[std_field] = std_value;
    return created;
}

godot::Variant GedisStore::hget(const godot::String &key, const godot::String &field, const godot::Variant &default_value) {
    std::string std_key = key.utf8().get_data();
    std::string std_field = field.utf8().get_data();

    if (!store.count(std_key) || store[std_key]->type != HASH) {
        return default_value;
    }

    auto* hash = store[std_key]->getHash();
    if (hash->count(std_field)) {
        std::string value_str = hash->at(std_field);
        // Try to convert to integer if it looks like a number
        try {
            int64_t int_val = std::stoll(value_str);
            return godot::Variant(int_val);
        } catch (...) {
            // If not a number, return as string
            return godot::String(value_str.c_str());
        }
    }

    return default_value;
}

godot::Dictionary GedisStore::hgetall(const godot::String &key) {
    godot::Dictionary result;
    std::string std_key = key.utf8().get_data();

    if (store.count(std_key) && store[std_key]->type == HASH) {
        auto* hash = store[std_key]->getHash();
        for (const auto& [field, value] : *hash) {
            // Try to convert to integer if it looks like a number
            try {
                int64_t int_val = std::stoll(value);
                result[godot::String(field.c_str())] = godot::Variant(int_val);
            } catch (...) {
                // If not a number, return as string
                result[godot::String(field.c_str())] = godot::String(value.c_str());
            }
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
            std::string std_field = godot::String(field_array[i]).utf8().get_data();
            if (hash->erase(std_field)) {
                deleted_count++;
            }
        }
    } else {
        // Single field
        std::string std_field = godot::String(fields).utf8().get_data();
        if (hash->erase(std_field)) {
            deleted_count++;
        }
    }
    
    return deleted_count;
}

bool GedisStore::hexists(const godot::String &key, const godot::String &field) {
    std::string std_key = key.utf8().get_data();
    std::string std_field = field.utf8().get_data();

    if (!store.count(std_key) || store[std_key]->type != HASH) {
        return false;
    }

    auto* hash = store[std_key]->getHash();
    return hash->count(std_field);
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
            // Try to convert to integer if it looks like a number
            try {
                int64_t int_val = std::stoll(value);
                result.append(godot::Variant(int_val));
            } catch (...) {
                // If not a number, return as string
                result.append(godot::String(value.c_str()));
            }
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
        store[std_key] = new GedisObject(LIST, new std::vector<std::string>());
    }

    auto* list = store[std_key]->getList();
    
    // Handle both single value and array of values
    if (values.get_type() == godot::Variant::ARRAY) {
        godot::Array value_array = values;
        for (int i = 0; i < value_array.size(); i++) {
            std::string value = godot::String(value_array[i]).utf8().get_data();
            list->insert(list->begin(), value);
        }
    } else {
        // Single value
        std::string value = godot::String(values).utf8().get_data();
        list->insert(list->begin(), value);
    }

    return list->size();
}

int64_t GedisStore::rpush(const godot::String &key, const godot::Variant &values) {
    std::string std_key = key.utf8().get_data();
    
    if (store.count(std_key) && store[std_key]->type != LIST) {
        return -1; // Wrong type
    }

    if (!store.count(std_key)) {
        store[std_key] = new GedisObject(LIST, new std::vector<std::string>());
    }

    auto* list = store[std_key]->getList();
    
    // Handle both single value and array of values
    if (values.get_type() == godot::Variant::ARRAY) {
        godot::Array value_array = values;
        for (int i = 0; i < value_array.size(); i++) {
            std::string value = godot::String(value_array[i]).utf8().get_data();
            list->push_back(value);
        }
    } else {
        // Single value
        std::string value = godot::String(values).utf8().get_data();
        list->push_back(value);
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
    // Try to convert to integer if it looks like a number
    try {
        int64_t int_val = std::stoll(value);
        return godot::Variant(int_val);
    } catch (...) {
        // If not a number, return as string
        return godot::String(value.c_str());
    }
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
    // Try to convert to integer if it looks like a number
    try {
        int64_t int_val = std::stoll(value);
        return godot::Variant(int_val);
    } catch (...) {
        // If not a number, return as string
        return godot::String(value.c_str());
    }
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
                // Try to convert to integer if it looks like a number
                std::string value_str = (*list)[i];
                try {
                    int64_t int_val = std::stoll(value_str);
                    result.append(godot::Variant(int_val));
                } catch (...) {
                    // If not a number, return as string
                    result.append(godot::String(value_str.c_str()));
                }
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

    // Try to convert to integer if it looks like a number
    std::string value_str = (*list)[index];
    try {
        int64_t int_val = std::stoll(value_str);
        return godot::Variant(int_val);
    } catch (...) {
        // If not a number, return as string
        return godot::String(value_str.c_str());
    }
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
        store[std_key] = new GedisObject(SET, new std::unordered_set<std::string>());
    }

    int64_t added_count = 0;
    auto* set = store[std_key]->getSet();
    
    // Handle both single member and array of members
    if (members.get_type() == godot::Variant::ARRAY) {
        godot::Array member_array = members;
        for (int i = 0; i < member_array.size(); i++) {
            std::string member = godot::String(member_array[i]).utf8().get_data();
            if (set->insert(member).second) {
                added_count++;
            }
        }
    } else {
        // Single member
        std::string member = godot::String(members).utf8().get_data();
        if (set->insert(member).second) {
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
            // Try to convert to integer if it looks like a number
            try {
                int64_t int_val = std::stoll(member);
                result.append(godot::Variant(int_val));
            } catch (...) {
                // If not a number, return as string
                result.append(godot::String(member.c_str()));
            }
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
    // Try to convert to integer if it looks like a number
    try {
        int64_t int_val = std::stoll(value);
        return godot::Variant(int_val);
    } catch (...) {
        // If not a number, return as string
        return godot::String(value.c_str());
    }
}

bool GedisStore::smove(const godot::String &source, const godot::String &destination, const godot::Variant &member) {
    std::string std_source = source.utf8().get_data();
    std::string std_dest = destination.utf8().get_data();
    std::string std_member = godot::String(member).utf8().get_data();

    if (!store.count(std_source) || store[std_source]->type != SET) {
        return false;
    }

    auto* source_set = store[std_source]->getSet();
    if (!source_set->count(std_member)) {
        return false;
    }

    // Create destination set if it doesn't exist
    if (!store.count(std_dest)) {
        store[std_dest] = new GedisObject(SET, new std::unordered_set<std::string>());
    } else if (store[std_dest]->type != SET) {
        return false;
    }

    auto* dest_set = store[std_dest]->getSet();
    
    // Move the member
    source_set->erase(std_member);
    dest_set->insert(std_member);
    
    return true;
}

// Pub/Sub commands
void GedisStore::subscribe(const godot::String &channel, godot::Object *subscriber) {
    std::string std_channel = channel.utf8().get_data();
    subscriptions[std_channel].push_back(subscriber);
}

void GedisStore::unsubscribe(const godot::String &channel, godot::Object *subscriber) {
    std::string std_channel = channel.utf8().get_data();
    if (subscriptions.count(std_channel)) {
        auto& subscribers = subscriptions[std_channel];
        subscribers.erase(std::remove(subscribers.begin(), subscribers.end(), subscriber), subscribers.end());
    }
}

void GedisStore::psubscribe(const godot::String &pattern, godot::Object *subscriber) {
    std::string std_pattern = pattern.utf8().get_data();
    psubscriptions[std_pattern].push_back(subscriber);
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