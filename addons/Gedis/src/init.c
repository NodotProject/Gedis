#include "init.h"

#include "api.h"
#include "gedis_core.h"

void initialize_gedis_module(void *p_userdata, GDExtensionInitializationLevel p_level)
{
    if (p_level != GDEXTENSION_INITIALIZATION_SCENE)
    {
        return;
    }

    // Register class.
    StringName class_name;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&class_name, "GedisCore");
    StringName parent_class_name;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&parent_class_name, "RefCounted");

    GDExtensionClassCreationInfo2 class_info = {
        .is_virtual = false,
        .is_abstract = false,
        .is_exposed = true,
        .set_func = NULL,
        .get_func = NULL,
        .get_property_list_func = NULL,
        .free_property_list_func = NULL,
        .property_can_revert_func = NULL,
        .property_get_revert_func = NULL,
        .validate_property_func = NULL,
        .notification_func = NULL,
        .to_string_func = NULL,
        .reference_func = NULL,
        .unreference_func = NULL,
        .create_instance_func = gedis_core_create_instance,
        .free_instance_func = gedis_core_free_instance,
        .recreate_instance_func = NULL,
        .get_virtual_func = NULL,
        .get_virtual_call_data_func = NULL,
        .call_virtual_with_data_func = NULL,
        .get_rid_func = NULL,
        .class_userdata = NULL,
    };

    api.classdb_register_extension_class2(class_library, (GDExtensionStringNamePtr)&class_name, (GDExtensionStringNamePtr)&parent_class_name, &class_info);

    // Bind methods.
    gedis_core_bind_methods();

    // Destruct things.
    destructors.string_name_destructor((GDExtensionStringNamePtr)&class_name);
    destructors.string_name_destructor((GDExtensionStringNamePtr)&parent_class_name);
}

void deinitialize_gedis_module(void *p_userdata, GDExtensionInitializationLevel p_level)
{
    if (p_level != GDEXTENSION_INITIALIZATION_SCENE)
    {
        return;
    }
}

GDExtensionBool GDE_EXPORT gedis_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
{
    class_library = p_library;
    load_api(p_get_proc_address);

    r_initialization->initialize = initialize_gedis_module;
    r_initialization->deinitialize = deinitialize_gedis_module;
    r_initialization->userdata = NULL;
    r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;

    return true;
}
