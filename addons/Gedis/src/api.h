#ifndef API_H
#define API_H

/*
This file works as a collection of helpers to call the GDExtension API
in a less verbose way, as well as a cache for methods from the discovery API,
just so we don't have to keep loading the same methods again.
*/

#include "gdextension_interface.h"

#include "defs.h"

extern GDExtensionClassLibraryPtr class_library;

// API methods.

struct Constructors
{
    GDExtensionInterfaceStringNameNewWithUtf8Chars string_name_new_with_utf8_chars;
    GDExtensionInterfaceStringNewWithUtf8Chars string_new_with_utf8_chars;
    GDExtensionVariantFromTypeConstructorFunc variant_from_float_constructor;
    GDExtensionTypeFromVariantConstructorFunc float_from_variant_constructor;
    GDExtensionVariantFromTypeConstructorFunc variant_from_int_constructor;
    GDExtensionTypeFromVariantConstructorFunc int_from_variant_constructor;
};

struct Destructors
{
    GDExtensionPtrDestructor string_name_destructor;
    GDExtensionPtrDestructor string_destructor;
};

struct API
{
    GDExtensionInterfaceClassdbRegisterExtensionClass2 classdb_register_extension_class2;
    GDExtensionInterfaceClassdbRegisterExtensionClassMethod classdb_register_extension_class_method;
    GDExtensionInterfaceClassdbConstructObject classdb_construct_object;
    GDExtensionInterfaceObjectSetInstance object_set_instance;
    GDExtensionInterfaceObjectSetInstanceBinding object_set_instance_binding;
    GDExtensionInterfaceMemAlloc mem_alloc;
    GDExtensionInterfaceMemFree mem_free;
    GDExtensionInterfaceGetVariantFromTypeConstructor get_variant_from_type_constructor;
    GDExtensionInterfaceGetVariantToTypeConstructor get_variant_to_type_constructor;
    GDExtensionInterfaceVariantGetType variant_get_type;
};

extern struct Constructors constructors;
extern struct Destructors destructors;
extern struct API api;

void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address);

// Create a PropertyInfo struct.
GDExtensionPropertyInfo make_property(
    GDExtensionVariantType type,
    const char *name);

GDExtensionPropertyInfo make_property_full(
    GDExtensionVariantType type,
    const char *name,
    uint32_t hint,
    const char *hint_string,
    const char *class_name,
    uint32_t usage_flags);

void destruct_property(GDExtensionPropertyInfo *info);

// Method binding helpers
void bind_method_0_r(
    const char *class_name,
    const char *method_name,
    void *function,
    GDExtensionVariantType return_type);

void bind_method_1(
    const char *class_name,
    const char *method_name,
    void *function,
    const char *arg1_name,
    GDExtensionVariantType arg1_type);

// Ptrcall wrappers
void ptrcall_0_args_ret_float(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);
void ptrcall_1_float_arg_no_ret(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);

// Call wrappers
void call_0_args_ret_float(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
void call_1_float_arg_no_ret(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
void bind_method_2_r(
    const char *class_name,
    const char *method_name,
    void *function,
    const char *arg1_name,
    GDExtensionVariantType arg1_type,
    const char *arg2_name,
    GDExtensionVariantType arg2_type,
    GDExtensionVariantType return_type);

// Ptrcall wrappers
void ptrcall_2_int_args_ret_int(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);

// Call wrappers
void call_2_int_args_ret_int(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);


#endif // API_H