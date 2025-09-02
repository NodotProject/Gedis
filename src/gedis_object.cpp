#include "gedis_object.h"
#include <godot_cpp/variant/string.hpp>
#include <vector>
#include <unordered_map>
#include <unordered_set>

GedisObject::GedisObject(GedisObjectType t, void* d) : type(t), data(d), expiration(-1) {}

GedisObject::~GedisObject() {
    if (data) {
        switch (type) {
            case STRING:
                delete static_cast<std::string*>(data);
                break;
            case LIST:
                delete static_cast<std::vector<std::string>*>(data);
                break;
            case HASH:
                delete static_cast<std::unordered_map<std::string, std::string>*>(data);
                break;
            case SET:
                delete static_cast<std::unordered_set<std::string>*>(data);
                break;
        }
    }
}