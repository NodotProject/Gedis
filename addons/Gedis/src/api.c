#include "api.h"
#include <string.h>

GDExtensionClassLibraryPtr class_library = NULL;
struct Constructors constructors;
struct Destructors destructors;
struct API api;

void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address)
{
    // Get helper functions first.
    GDExtensionInterfaceVariantGetPtrDestructor variant_get_ptr_destructor = (GDExtensionInterfaceVariantGetPtrDestructor)p_get_proc_address("variant_get_ptr_destructor");

    // API.
    api.classdb_register_extension_class2 = (GDExtensionInterfaceClassdbRegisterExtensionClass2)p_get_proc_address("classdb_register_extension_class2");
    api.classdb_register_extension_class_method = (GDExtensionInterfaceClassdbRegisterExtensionClassMethod)p_get_proc_address("classdb_register_extension_class_method");
    api.classdb_construct_object = (GDExtensionInterfaceClassdbConstructObject)p_get_proc_address("classdb_construct_object");
    api.object_set_instance = (GDExtensionInterfaceObjectSetInstance)p_get_proc_address("object_set_instance");
    api.object_set_instance_binding = (GDExtensionInterfaceObjectSetInstanceBinding)p_get_proc_address("object_set_instance_binding");
    api.mem_alloc = (GDExtensionInterfaceMemAlloc)p_get_proc_address("mem_alloc");
    api.mem_free = (GDExtensionInterfaceMemFree)p_get_proc_address("mem_free");
    api.get_variant_from_type_constructor = (GDExtensionInterfaceGetVariantFromTypeConstructor)p_get_proc_address("get_variant_from_type_constructor");
    api.get_variant_to_type_constructor = (GDExtensionInterfaceGetVariantToTypeConstructor)p_get_proc_address("get_variant_to_type_constructor");
    api.variant_get_type = (GDExtensionInterfaceVariantGetType)p_get_proc_address("variant_get_type");

    // Constructors.
    constructors.string_name_new_with_utf8_chars = (GDExtensionInterfaceStringNameNewWithUtf8Chars)p_get_proc_address("string_name_new_with_utf8_chars");
    constructors.string_new_with_utf8_chars = (GDExtensionInterfaceStringNewWithUtf8Chars)p_get_proc_address("string_new_with_utf8_chars");
    constructors.variant_from_float_constructor = api.get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
    constructors.float_from_variant_constructor = api.get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
    constructors.variant_from_int_constructor = api.get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);
    constructors.int_from_variant_constructor = api.get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);

    // Destructors.
    destructors.string_name_destructor = variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    destructors.string_destructor = variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
}

GDExtensionPropertyInfo make_property(
    GDExtensionVariantType type,
    const char *name)
{
    return make_property_full(type, name, PROPERTY_HINT_NONE, "", "", PROPERTY_USAGE_DEFAULT);
}

GDExtensionPropertyInfo make_property_full(
    GDExtensionVariantType type,
    const char *name,
    uint32_t hint,
    const char *hint_string,
    const char *class_name,
    uint32_t usage_flags)
{
    StringName *prop_name = api.mem_alloc(sizeof(StringName));
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)prop_name, name);
    String *prop_hint_string = api.mem_alloc(sizeof(String));
    constructors.string_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)prop_hint_string, hint_string);
    StringName *prop_class_name = api.mem_alloc(sizeof(StringName));
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)prop_class_name, class_name);

    GDExtensionPropertyInfo info = {
        .name = (GDExtensionStringNamePtr)prop_name,
        .type = type,
        .hint = hint,
        .hint_string = (GDExtensionStringPtr)prop_hint_string,
        .class_name = (GDExtensionStringNamePtr)prop_class_name,
        .usage = usage_flags,
    };

    return info;
}

void destruct_property(GDExtensionPropertyInfo *info)
{
    destructors.string_name_destructor((GDExtensionStringNamePtr)info->name);
    destructors.string_destructor((GDExtensionStringPtr)info->hint_string);
    destructors.string_name_destructor((GDExtensionStringNamePtr)info->class_name);
    api.mem_free(info->name);
    api.mem_free(info->hint_string);
    api.mem_free(info->class_name);
}

void bind_method_0_r(
    const char *class_name,
    const char *method_name,
    void *function,
    GDExtensionVariantType return_type)
{
    StringName method_name_string;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&method_name_string, method_name);

    GDExtensionClassMethodCall call_func = call_0_args_ret_float;
    GDExtensionClassMethodPtrCall ptrcall_func = ptrcall_0_args_ret_float;

    GDExtensionPropertyInfo return_info = make_property(return_type, "");

    GDExtensionClassMethodInfo method_info = {
        .name = (GDExtensionStringNamePtr)&method_name_string,
        .method_userdata = function,
        .call_func = call_func,
        .ptrcall_func = ptrcall_func,
        .method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT,
        .has_return_value = true,
        .return_value_info = &return_info,
        .return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
        .argument_count = 0,
    };

    StringName class_name_string;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&class_name_string, class_name);

    api.classdb_register_extension_class_method(class_library, (GDExtensionStringNamePtr)&class_name_string, &method_info);

    // Destruct things.
    destructors.string_name_destructor((GDExtensionStringNamePtr)&method_name_string);
    destructors.string_name_destructor((GDExtensionStringNamePtr)&class_name_string);
    destruct_property(&return_info);
}

void bind_method_1(
    const char *class_name,
    const char *method_name,
    void *function,
    const char *arg1_name,
    GDExtensionVariantType arg1_type)
{
    StringName method_name_string;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&method_name_string, method_name);

    GDExtensionClassMethodCall call_func = call_1_float_arg_no_ret;
    GDExtensionClassMethodPtrCall ptrcall_func = ptrcall_1_float_arg_no_ret;

    GDExtensionPropertyInfo args_info[] = {
        make_property(arg1_type, arg1_name),
    };
    GDExtensionClassMethodArgumentMetadata args_metadata[] = {
        GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
    };

    GDExtensionClassMethodInfo method_info = {
        .name = (GDExtensionStringNamePtr)&method_name_string,
        .method_userdata = function,
        .call_func = call_func,
        .ptrcall_func = ptrcall_func,
        .method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT,
        .has_return_value = false,
        .argument_count = 1,
        .arguments_info = args_info,
        .arguments_metadata = args_metadata,
    };

    StringName class_name_string;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&class_name_string, class_name);

    api.classdb_register_extension_class_method(class_library, (GDExtensionStringNamePtr)&class_name_string, &method_info);

    // Destruct things.
    destructors.string_name_destructor((GDExtensionStringNamePtr)&method_name_string);
    destructors.string_name_destructor((GDExtensionStringNamePtr)&class_name_string);
    destruct_property(&args_info[0]);
}

void bind_method_2_r(
    const char *class_name,
    const char *method_name,
    void *function,
    const char *arg1_name,
    GDExtensionVariantType arg1_type,
    const char *arg2_name,
    GDExtensionVariantType arg2_type,
    GDExtensionVariantType return_type)
{
    StringName method_name_string;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&method_name_string, method_name);

    GDExtensionClassMethodCall call_func = call_2_int_args_ret_int;
    GDExtensionClassMethodPtrCall ptrcall_func = ptrcall_2_int_args_ret_int;

    GDExtensionPropertyInfo return_info = make_property(return_type, "");

    GDExtensionPropertyInfo args_info[] = {
        make_property(arg1_type, arg1_name),
        make_property(arg2_type, arg2_name),
    };
    GDExtensionClassMethodArgumentMetadata args_metadata[] = {
        GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
        GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
    };

    GDExtensionClassMethodInfo method_info = {
        .name = (GDExtensionStringNamePtr)&method_name_string,
        .method_userdata = function,
        .call_func = call_func,
        .ptrcall_func = ptrcall_func,
        .method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT,
        .has_return_value = true,
        .return_value_info = &return_info,
        .return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
        .argument_count = 2,
        .arguments_info = args_info,
        .arguments_metadata = args_metadata,
    };

    StringName class_name_string;
    constructors.string_name_new_with_utf8_chars((GDExtensionUninitializedStringNamePtr)&class_name_string, class_name);

    api.classdb_register_extension_class_method(class_library, (GDExtensionStringNamePtr)&class_name_string, &method_info);

    // Destruct things.
    destructors.string_name_destructor((GDExtensionStringNamePtr)&method_name_string);
    destructors.string_name_destructor((GDExtensionStringNamePtr)&class_name_string);
    destruct_property(&return_info);
    destruct_property(&args_info[0]);
    destruct_property(&args_info[1]);
}

void ptrcall_0_args_ret_float(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret)
{
    // Call the function.
    double (*function)(void *) = method_userdata;
    *((double *)r_ret) = function(p_instance);
}

void ptrcall_1_float_arg_no_ret(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret)
{
    // Call the function.
    void (*function)(void *, double) = method_userdata;
    function(p_instance, *((double *)p_args[0]));
}

void ptrcall_2_int_args_ret_int(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret)
{
    // Call the function.
    GDExtensionInt (*function)(GDExtensionInt, GDExtensionInt) = method_userdata;
    *((GDExtensionInt *)r_ret) = function(*((GDExtensionInt *)p_args[0]), *((GDExtensionInt *)p_args[1]));
}

void call_0_args_ret_float(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error)
{
    // Check argument count.
    if (p_argument_count != 0)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        r_error->expected = 0;
        return;
    }

    // Call the function.
    double (*function)(void *) = method_userdata;
    double result = function(p_instance);
    // Set resulting Variant.
    constructors.variant_from_float_constructor(r_return, &result);
}

void call_1_float_arg_no_ret(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error)
{
    // Check argument count.
    if (p_argument_count < 1)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
        r_error->expected = 1;
        return;
    }
    else if (p_argument_count > 1)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        r_error->expected = 1;
        return;
    }

    // Check the argument type.
    GDExtensionVariantType type = api.variant_get_type(p_args[0]);
    if (type != GDEXTENSION_VARIANT_TYPE_FLOAT)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        r_error->expected = GDEXTENSION_VARIANT_TYPE_FLOAT;
        r_error->argument = 0;
        return;
    }

    // Extract the argument.
    double arg1;
    constructors.float_from_variant_constructor(&arg1, (GDExtensionVariantPtr)p_args[0]);

    // Call the function.
    void (*function)(void *, double) = method_userdata;
    function(p_instance, arg1);
}

void call_2_int_args_ret_int(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error)
{
    // Check argument count.
    if (p_argument_count < 2)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
        r_error->expected = 2;
        return;
    }
    else if (p_argument_count > 2)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        r_error->expected = 2;
        return;
    }

    // Check the argument types.
    GDExtensionVariantType type1 = api.variant_get_type(p_args[0]);
    if (type1 != GDEXTENSION_VARIANT_TYPE_INT)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        r_error->expected = GDEXTENSION_VARIANT_TYPE_INT;
        r_error->argument = 0;
        return;
    }
    GDExtensionVariantType type2 = api.variant_get_type(p_args[1]);
    if (type2 != GDEXTENSION_VARIANT_TYPE_INT)
    {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        r_error->expected = GDEXTENSION_VARIANT_TYPE_INT;
        r_error->argument = 1;
        return;
    }

    // Extract the arguments.
    GDExtensionInt arg1, arg2;
    constructors.int_from_variant_constructor(&arg1, (GDExtensionVariantPtr)p_args[0]);
    constructors.int_from_variant_constructor(&arg2, (GDExtensionVariantPtr)p_args[1]);

    // Call the function.
    GDExtensionInt (*function)(GDExtensionInt, GDExtensionInt) = method_userdata;
    GDExtensionInt result = function(arg1, arg2);
    // Set resulting Variant.
    constructors.variant_from_int_constructor(r_return, &result);
}