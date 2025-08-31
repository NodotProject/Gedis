#ifndef GEDIS_OBJECT_H
#define GEDIS_OBJECT_H

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>
#include <unordered_set>

enum GedisObjectType {
    STRING,
    LIST,
    HASH,
    SET
};

struct GedisObject {
    GedisObjectType type;
    void* data;
    int64_t expiration; // Using int64_t for timestamp

    GedisObject(GedisObjectType t, void* d);
    ~GedisObject();

    // Helper methods to access data
    std::string* getString() const { return static_cast<std::string*>(data); }
    std::vector<std::string>* getList() const { return static_cast<std::vector<std::string>*>(data); }
    std::unordered_map<std::string, std::string>* getHash() const { return static_cast<std::unordered_map<std::string, std::string>*>(data); }
    std::unordered_set<std::string>* getSet() const { return static_cast<std::unordered_set<std::string>*>(data); }
};

#endif // GEDIS_OBJECT_H