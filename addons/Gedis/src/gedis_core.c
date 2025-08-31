#include "gedis_core.h"

#include "api.h"

void gedis_core_constructor(GedisCore *self)
{
    self->amplitude = 10.0;
    self->speed = 1.0;
}

void gedis_core_destructor(GedisCore *self)
{
}

void gedis_core_set_amplitude(GedisCore *self, double amplitude)
{
    self->amplitude = amplitude;
}

double gedis_core_get_amplitude(const GedisCore *self)
{
    return self->amplitude;
}

void gedis_core_set_speed(GedisCore *self, double speed)
{
    self->speed = speed;
}

double gedis_core_get_speed(const GedisCore *self)
{
    return self->speed;
}

void gedis_core_bind_methods()
{
    bind_method_0_r("GedisCore", "get_amplitude", gedis_core_get_amplitude, GDEXTENSION_VARIANT_TYPE_FLOAT);
    bind_method_1("GedisCore", "set_amplitude", gedis_core_set_amplitude, "amplitude", GDEXTENSION_VARIANT_TYPE_FLOAT);

    bind_method_0_r("GedisCore", "get_speed", gedis_core_get_speed, GDEXTENSION_VARIANT_TYPE_FLOAT);
    bind_method_1("GedisCore", "set_speed", gedis_core_set_speed, "speed", GDEXTENSION_VARIANT_TYPE_FLOAT);

    bind_method_2_r("GedisCore", "add", gedis_core_add, "a", GDEXTENSION_VARIANT_TYPE_INT, "b", GDEXTENSION_VARIANT_TYPE_INT, GDEXTENSION_VARIANT_TYPE_INT);
}

GDExtensionInt gedis_core_add(GDExtensionInt a, GDExtensionInt b)
{
    return a + b;
}

const GDExtensionInstanceBindingCallbacks gedis_core_binding_callbacks = {
    .create_callback = NULL,
    .free_callback = NULL,
    .reference_callback = NULL,
};

GDExtensionObjectPtr gedis_core_create_instance(void *p_class_userdata)
{
    // Create native Godot object;
    StringName class_name;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&class_name, "RefCounted");
    GDExtensionObjectPtr object = api.classdb_construct_object((GDExtensionStringNamePtr)&class_name);
    destructors.string_name_destructor((GDExtensionStringNamePtr)&class_name);

    // Create extension object.
    GedisCore *self = (GedisCore *)api.mem_alloc(sizeof(GedisCore));
    gedis_core_constructor(self);
    self->object = object;

    // Set the extension instance in the native Godot object.
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&class_name, "GedisCore");
    api.object_set_instance(object, (GDExtensionStringNamePtr)&class_name, self);
    api.object_set_instance_binding(object, class_library, self, &gedis_core_binding_callbacks);
    destructors.string_name_destructor((GDExtensionStringNamePtr)&class_name);

    return object;
}

void gedis_core_free_instance(void *p_class_userdata, GDExtensionClassInstancePtr p_instance)
{
    if (p_instance == NULL)
    {
        return;
    }
    GedisCore *self = (GedisCore *)p_instance;
    gedis_core_destructor(self);
    api.mem_free(self);
}