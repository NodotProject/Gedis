#ifndef GEDIS_CORE_H
#define GEDIS_CORE_H

#include "gdextension_interface.h"

#include "defs.h"

// Struct to hold the node data.
typedef struct
{
    // Public properties.
    double amplitude;
    double speed;
    // Metadata.
    GDExtensionObjectPtr object; // Stores the underlying Godot object.
} GedisCore;

// Constructor for the node.
void gedis_core_constructor(GedisCore *self);

// Destructor for the node.
void gedis_core_destructor(GedisCore *self);

// Properties.
void gedis_core_set_amplitude(GedisCore *self, double amplitude);
// Methods
GDExtensionInt gedis_core_add(GDExtensionInt a, GDExtensionInt b);
double gedis_core_get_amplitude(const GedisCore *self);
void gedis_core_set_speed(GedisCore *self, double speed);
double gedis_core_get_speed(const GedisCore *self);

// Bindings.
void gedis_core_bind_methods();
GDExtensionObjectPtr gedis_core_create_instance(void *p_class_userdata);
void gedis_core_free_instance(void *p_class_userdata, GDExtensionClassInstancePtr p_instance);

#endif // GEDIS_CORE_H