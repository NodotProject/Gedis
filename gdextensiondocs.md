Initializing the extension

The first bit of code will be responsible for initializing the extension. This is what makes Godot aware of what our GDExtension provides, such as classes and plugins.

Create the file init.h in the src folder, with the following contents:

#ifndef INIT_H
#define INIT_H

#include "defs.h"

#include "gdextension_interface.h"

void initialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level);
void deinitialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level);
GDExtensionBool GDE_EXPORT gdexample_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization);

#endif // INIT_H

The functions declared here have the signatures expected by the GDExtension API.

Note the inclusion of the defs.h file. This is one of our helpers to simplify writing the extension code. For now it will only contain the definition of GDE_EXPORT, a macro that makes the function public in the shared library so Godot can properly call it. This macro helps abstracting what each compiler expects.

Create the defs.h file in the src folder with the following contents:

#ifndef DEFS_H
#define DEFS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if !defined(GDE_EXPORT)
#if defined(_WIN32)
#define GDE_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define GDE_EXPORT __attribute__((visibility("default")))
#else
#define GDE_EXPORT
#endif
#endif // ! GDE_EXPORT

#endif // DEFS_H

We also include some standard headers to make things easier. Now we only have to include defs.h and those will come as a bonus.

Now, let's implement the functions we just declared. Create a file called init.c in the src folder and add this code:

#include "init.h"

void initialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level)
{
}

void deinitialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level)
{
}

GDExtensionBool GDE_EXPORT gdexample_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
{
    r_initialization->initialize = initialize_gdexample_module;
    r_initialization->deinitialize = deinitialize_gdexample_module;
    r_initialization->userdata = NULL;
    r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;

    return true;
}

What this does is set up the initialization data that Godot expects. The functions to initialize and deinitialize are set so Godot will call then when needed. It also sets the initialization level which varies per extension. Since we plan to add a custom node, the SCENE level is enough.

We will fill the initialize_gdexample_module() function later to register our custom class.
A basic class

In order to make an actual node, first we'll create a C struct to hold data and functions that will act as methods. The plan is to make this a custom node that inherits from Sprite2D.

Create a file called gdexample.h in the src folder with the following contents:

#ifndef GDEXAMPLE_H
#define GDEXAMPLE_H

#include "gdextension_interface.h"

#include "defs.h"

// Struct to hold the node data.
typedef struct
{
    // Metadata.
    GDExtensionObjectPtr object; // Stores the underlying Godot object.
} GDExample;

// Constructor for the node.
void gdexample_class_constructor(GDExample *self);

// Destructor for the node.
void gdexample_class_destructor(GDExample *self);

// Bindings.
void gdexample_class_bind_methods();

#endif // GDEXAMPLE_H

Noteworthy here is the object field, which holds a pointer to the Godot object, and the gdexample_class_bind_methods() function, which will register the metadata of our custom class (properties, methods, and signals). The latter is not entirely necessary, as we can do it when registering the class, but it makes clearer to separate the concerns and let our class register its own metadata.

The object field is necessary because our class will inherit a Godot class. Since we can't inherit it directly, as we are not interacting with the source code (and C doesn't even have classes), we instead tell Godot to create an object of a type it knows and attach our extension to it. We will need the reference to such objects when calling methods on the parent class, for instance.

Let's create the source counterpart of this header. Create the file gdexample.c in the src folder and add the following code to it:

#include "gdexample.h"

void gdexample_class_constructor(GDExample *self)
{
}

void gdexample_class_destructor(GDExample *self)
{
}

void gdexample_class_bind_methods()
{
}

As we don't have anything to do with those functions yet, they'll stay empty for a while.

The next step is registering our class. However, in order to do so we need to create a StringName and for that we have to get a function from the GDExtension API. Since we'll need this a few times and we'll also need other things, let's create a wrapper API to facilitate this kind of chore.
A wrapper API

We'll start by creating an api.h file in the src folder:

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
    GDExtensionInterfaceStringNameNewWithLatin1Chars string_name_new_with_latin1_chars;
} constructors;

struct Destructors
{
    GDExtensionPtrDestructor string_name_destructor;
} destructors;

struct API
{
    GDExtensionInterfaceClassdbRegisterExtensionClass2 classdb_register_extension_class2;
} api;

void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address);



#endif // API_H

This file will include many other helpers as we fill our extension with something useful. For now it only has a pointer to a function that creates a StringName from a C string (in Latin-1 encoding) and another to destruct a StringName, which we'll need to use to avoid leaking memory, as well as the function to register a class, which is our initial goal.

We also keep a reference to the class_library here. This is something that Godot provides to us when initializing the extension and we'll need to use it when registering the things we create so Godot can tell which extension is making the call.

There's also a function to load those function pointers from the GDExtension API.

Let's work on the source counterpart of this header. Create the api.c file in the src folder, adding the following code:

#include "api.h"

GDExtensionClassLibraryPtr class_library = NULL;

void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address)
{
    // Get helper functions first.
    GDExtensionInterfaceVariantGetPtrDestructor variant_get_ptr_destructor = (GDExtensionInterfaceVariantGetPtrDestructor)p_get_proc_address("variant_get_ptr_destructor");

    // API.
    api.classdb_register_extension_class2 = p_get_proc_address("classdb_register_extension_class2");

    // Constructors.
    constructors.string_name_new_with_latin1_chars = p_get_proc_address("string_name_new_with_latin1_chars");

    // Destructors.
    destructors.string_name_destructor = variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
}

The first important thing here is p_get_proc_address. This a function from the GDExtension API that is passed during initialization. You can use this function to request specific functions from the API by their name. Here we are caching the results so we don't have to keep a reference for p_get_proc_address everywhere and use our wrapper instead.

At the start we request the variant_get_ptr_destructor() function. This is not going to be used outside of this function, so we don't add to our wrapper and only cache it locally. The cast is necessary to silence compiler warnings.

Then we get the function that creates a StringName from a C string, exactly what we mentioned before as a needed function. We store that in our constructors struct.

Next, we use the variant_get_ptr_destructor() function we just got to query for the destructor for StringName, using the enum value from gdextension_interface.h API as a parameter. We could get destructors for other types in a similar manner, but we'll limit ourselves to what is needed for the example.

Lastly, we get the classdb_register_extension_class2() function, which we'll need in order to register our custom class.

Note

You may wonder why the 2 is there in the function name. This means it's the second version of this function. The old version is kept to ensure backwards compatibility with older extensions, but since we have the second version available, it's best to use the new one, because we don't intend to support older Godot versions in this example.

The gdextension_interface.h header documents in which Godot version each function was introduced.

We also define the class_library variable here, which will be set during initialization.

Speaking of initialization, now we have to change the init.c file in order to fill the things we just added:

GDExtensionBool GDE_EXPORT gdexample_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
{
    class_library = p_library;
    load_api(p_get_proc_address);

    ...

Here we set the class_library as needed and call our new load_api() function. Don't forget to also include the new headers at the top of this file:

#include "init.h"

#include "api.h"
#include "gdexample.h"
...

Since we are here, we can register our new custom class. Let's fill the initialize_gdexample_module() function:

void initialize_gdexample_module(void *p_userdata, GDExtensionInitializationLevel p_level)
{
    if (p_level != GDEXTENSION_INITIALIZATION_SCENE)
    {
        return;
    }

    // Register class.
    StringName class_name;
    constructors.string_name_new_with_latin1_chars(&class_name, "GDExample", false);
    StringName parent_class_name;
    constructors.string_name_new_with_latin1_chars(&parent_class_name, "Sprite2D", false);

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
        .create_instance_func = gdexample_class_create_instance,
        .free_instance_func = gdexample_class_free_instance,
        .recreate_instance_func = NULL,
        .get_virtual_func = NULL,
        .get_virtual_call_data_func = NULL,
        .call_virtual_with_data_func = NULL,
        .get_rid_func = NULL,
        .class_userdata = NULL,
    };

    api.classdb_register_extension_class2(class_library, &class_name, &parent_class_name, &class_info);

    // Bind methods.
    gdexample_class_bind_methods();

    // Destruct things.
    destructors.string_name_destructor(&class_name);
    destructors.string_name_destructor(&parent_class_name);
}

The struct with the class information is the biggest thing here. None of its fields are required with the exception of create_instance_func and free_instance_func. We haven't made those functions yet, so we'll have to work on them soon. Note that we skip the initialization if it isn't at the SCENE level. This function may be called multiple times, once for each level, but we only want to register our class once.

The other undefined thing here is StringName. This will be an opaque struct meant to hold the data of a Godot StringName in our extension. We'll define it in the appropriately named defs.h file:

...
// The sizes can be obtained from the extension_api.json file.
#ifdef BUILD_32
#define STRING_NAME_SIZE 4
#else
#define STRING_NAME_SIZE 8
#endif

// Types.

typedef struct
{
    uint8_t data[STRING_NAME_SIZE];
} StringName;

#endif // DEFS_H

As mentioned in the comment, the sizes can be found in the extension_api.json file that we generated earlier, under the builtin_class_sizes property. The BUILD_32 is never defined, as we assume we are working with a 64-bits build of Godot here, but if you need it you can add env.Append(CPPDEFINES=["BUILD_32"]) to your SConstruct file.

The // Types. comment foreshadows that we'll be adding more types to this file. Let's leave that for later.

The StringName struct here is just to hold Godot data, so we don't really care what is inside of it. Though, in this case, it is just a pointer to the data in the heap. We'll use this struct when we need to allocate data for a StringName ourselves, like we are doing when registering our class.

Back to registering, we need to work on our create and free functions. Let's include them in gdexample.h since they're specific to the custom class:

...
// Bindings.
void gdexample_class_bind_methods();
GDExtensionObjectPtr gdexample_class_create_instance(void *p_class_userdata);
void gdexample_class_free_instance(void *p_class_userdata, GDExtensionClassInstancePtr p_instance);
...

Before we can implement those function, we'll need a few more things in our API. We need a way to allocate and free memory. While we could do this with good ol' malloc(), we can instead make use of Godot's memory management functions. We'll also need a way to create a Godot object and set it with our custom instance.

So let's change the api.h to include these new functions:

...
struct API
{
    GDExtensionInterfaceClassdbRegisterExtensionClass2 classdb_register_extension_class2;
    GDExtensionInterfaceClassdbConstructObject classdb_construct_object;
    GDExtensionInterfaceObjectSetInstance object_set_instance;
    GDExtensionInterfaceObjectSetInstanceBinding object_set_instance_binding;
    GDExtensionInterfaceMemAlloc mem_alloc;
    GDExtensionInterfaceMemFree mem_free;
} api;

Then we change the load_api() function in api.c to grab these new functions:

...
void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address)
{
    ...
    // API.
    api.classdb_register_extension_class2 = p_get_proc_address("classdb_register_extension_class2");
    api.classdb_construct_object = (GDExtensionInterfaceClassdbConstructObject)p_get_proc_address("classdb_construct_object");
    api.object_set_instance = p_get_proc_address("object_set_instance");
    api.object_set_instance_binding = p_get_proc_address("object_set_instance_binding");
    api.mem_alloc = (GDExtensionInterfaceMemAlloc)p_get_proc_address("mem_alloc");
    api.mem_free = (GDExtensionInterfaceMemFree)p_get_proc_address("mem_free");
}

Now we can go back to gdexample.c and define the new functions, without forgetting to include the api.h header:

#include "gdexample.h"

#include "api.h"

...

const GDExtensionInstanceBindingCallbacks gdexample_class_binding_callbacks = {
    .create_callback = NULL,
    .free_callback = NULL,
    .reference_callback = NULL,
};

GDExtensionObjectPtr gdexample_class_create_instance(void *p_class_userdata)
{
    // Create native Godot object;
    StringName class_name;
    constructors.string_name_new_with_latin1_chars(&class_name, "Sprite2D", false);
    GDExtensionObjectPtr object = api.classdb_construct_object(&class_name);
    destructors.string_name_destructor(&class_name);

    // Create extension object.
    GDExample *self = (GDExample *)api.mem_alloc(sizeof(GDExample));
    gdexample_class_constructor(self);
    self->object = object;

    // Set the extension instance in the native Godot object.
    constructors.string_name_new_with_latin1_chars(&class_name, "GDExample", false);
    api.object_set_instance(object, &class_name, self);
    api.object_set_instance_binding(object, class_library, self, &gdexample_class_binding_callbacks);
    destructors.string_name_destructor(&class_name);

    return object;
}

void gdexample_class_free_instance(void *p_class_userdata, GDExtensionClassInstancePtr p_instance)
{
    if (p_instance == NULL)
    {
        return;
    }
    GDExample *self = (GDExample *)p_instance;
    gdexample_class_destructor(self);
    api.mem_free(self);
}

When instantiating an object, first we create a new Sprite2D object, since that's the parent of our class. Then we allocate memory for our custom struct and call its constructor. We save the pointer to the Godot object in the struct as well like we mentioned earlier.

Then we set our custom struct as the instance data. This will make Godot know that the object is an instance of our custom class and properly call our custom methods for instance, as well as passing this data back.

Note that we return the Godot object we created, not our custom struct.

For the gdextension_free_instance() function, we only call the destructor and free the memory we allocated for the custom data. It is not necessary to destruct the Godot object since that will be taken care of by the engine itself.

Custom methods

A common thing in extensions is creating methods for the custom classes and exposing those to the Godot API. We are going to create a couple of getters and setters which are need for binding the properties afterwards.

First, let's add the new fields in our struct to hold the values for amplitude and speed, which we will use later on when creating the behavior for the node. Add them to the gdexample.h file, changing the GDExample struct:

...

typedef struct
{
    // Public properties.
    double amplitude;
    double speed;
    // Metadata.
    GDExtensionObjectPtr object; // Stores the underlying Godot object.
} GDExample;

...

In the same file, add the declaration for the getters and setters, right after the destructor.

...

// Destructor for the node.
void gdexample_class_destructor(GDExample *self);

// Properties.
void gdexample_class_set_amplitude(GDExample *self, double amplitude);
double gdexample_class_get_amplitude(const GDExample *self);
void gdexample_class_set_speed(GDExample *self, double speed);
double gdexample_class_get_speed(const GDExample *self);

...

In the gdexample.c file, we will initialize these values in the constructor and add the implementations for those new functions, which are quite trivial:

void gdexample_class_constructor(GDExample *self)
{
    self->amplitude = 10.0;
    self->speed = 1.0;
}

void gdexample_class_set_amplitude(GDExample *self, double amplitude)
{
    self->amplitude = amplitude;
}

double gdexample_class_get_amplitude(const GDExample *self)
{
    return self->amplitude;
}

void gdexample_class_set_speed(GDExample *self, double speed)
{
    self->speed = speed;
}

double gdexample_class_get_speed(const GDExample *self)
{
    return self->speed;
}

To make those simple functions work when called by Godot, we will need some wrappers to help us properly convert the data to and from the engine.

First, we will create wrappers for ptrcall. This is what Godot uses when the types of the values are known to be exact, which avoids using Variant. We're gonna need two of those: one for the functions that take no arguments and return a double (for the getters) and another for the functions that take a single double argument and return nothing (for the setters).

Add the declarations to the api.h file:

void ptrcall_0_args_ret_float(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);
void ptrcall_1_float_arg_no_ret(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);

Those two functions follow the GDExtensionClassMethodPtrCall type, as defined in the gdextension_interface.h. We use float as a name here because in Godot the float type has double precision, so we keep this convention.

Then we implement those functions in the api.c file:

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

The method_userdata argument is a custom value that we give to Godot, in this case we will set as the function pointer for the one we want to call. So first we convert it to the function type, then we just call it by passing the arguments when needed, or setting the return value.

The p_instance argument contains the custom instance of our class, which we gave with object_set_instance() when creating the object.

p_args is an array of arguments. Note this contains pointers to the values. That's why we dereference it when passing to our functions. The number of arguments will be declared when binding the function (which we will do soon) and it will always include default ones if those exist.

Finally, the r_ret is a pointer to the variable where the return value needs to be set. Like the arguments, it will be the correct type as declared. For the function that does not return, we have to avoid setting it.

Note how the type and argument counts are exact, so if we needed different types, for example, we would have to create more wrappers. This could be automated using some code generation, but this is out of the scope for this tutorial.

While the ptrcall functions are used when types are exact, sometimes Godot cannot know if that's the case (when the call comes from a dynamically typed language, such as GDScript). In those situations it uses regular call functions, so we need to provide those as well when binding.

Let's create two new wrappers in the api.h file:

void call_0_args_ret_float(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
void call_1_float_arg_no_ret(void *method_userdata, GDExtensionClassInstancePtr p_instance, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);

These follow the GDExtensionClassMethodCall type, which is a bit different. First, you receive pointers to Variants instead of exact types. There's also the amount of arguments and an error struct that you can set if something goes wrong.

In order to check the type and also extract interact with Variant, we will need a few more functions from the GDExtension API. So let's expand our wrapper structs:

struct Constructors {
    ...
    GDExtensionVariantFromTypeConstructorFunc variant_from_float_constructor;
    GDExtensionTypeFromVariantConstructorFunc float_from_variant_constructor;
} constructors;

struct API
{
    ...
    GDExtensionInterfaceGetVariantFromTypeConstructor get_variant_from_type_constructor;
    GDExtensionInterfaceGetVariantToTypeConstructor get_variant_to_type_constructor;
    GDExtensionInterfaceVariantGetType variant_get_type;
} api;

The names say all about what those do. We have a couple of constructors to create and extract a floating point value to and from a Variant. We also have a couple of helpers to actually get those constructors, as well as a function to find out the type of a Variant.

Let's get those from the API, like we did before, by changing the load_api() function in the api.c file:

void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address)
{
    ...

    // API.
    ...
    api.get_variant_from_type_constructor = (GDExtensionInterfaceGetVariantFromTypeConstructor)p_get_proc_address("get_variant_from_type_constructor");
    api.get_variant_to_type_constructor = (GDExtensionInterfaceGetVariantToTypeConstructor)p_get_proc_address("get_variant_to_type_constructor");
    api.variant_get_type = (GDExtensionInterfaceVariantGetType)p_get_proc_address("variant_get_type");
    ...

    // Constructors.
    ...
    constructors.variant_from_float_constructor = api.get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
    constructors.float_from_variant_constructor = api.get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
    ...
}

Now that we have these set, we can implement our call wrappers in the same file:

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

These functions are a bit longer but easy to follow. First they check if the argument count is as expected and if not they set the error struct and return. For the one that has one parameter, it also checks if the argument type is correct. This is important because mismatched types when extracting from Variant can cause crashes.

Then it proceeds to extract the argument using the constructor we setup before. The one with no arguments instead sets the return value after calling the function. Note how they use a pointer to a double variable, since this is what those constructors expect.

Before we can actually bind our methods, we need a way to create GDExtensionPropertyInfo instances. While we could do them inside the binding functions that we'll implement afterwards, it's easier to have a helper for it since we'll need it multiple times, including for when we bind properties.

Let's create these two functions in the api.h file:

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

The first one is a simplified version of the second since we usually don't need all the arguments for the property and are okay with the defaults. Then we also have a function to destruct the PropertyInfo since we need to create Strings and StringNames that need to be properly disposed of.

Speaking of which, we also need a way to create and destruct Strings, so we'll make an addition to existing structs in this same file. We'll also get a new API function for actually binding our custom method.

struct Constructors
{
    ...
    GDExtensionInterfaceStringNewWithUtf8Chars string_new_with_utf8_chars;
} constructors;

struct Destructors
{
    ...
    GDExtensionPtrDestructor string_destructor;
} destructors;

struct API
{
    ...
    GDExtensionInterfaceClassdbRegisterExtensionClassMethod classdb_register_extension_class_method;
} api;

Before implementing those, let's do a quick stop in the defs.h file and include the size of the String type and a couple of enums:

// The sizes can be obtained from the extension_api.json file.
#ifdef BUILD_32
#define STRING_SIZE 4
#define STRING_NAME_SIZE 4
#else
#define STRING_SIZE 8
#define STRING_NAME_SIZE 8
#endif

...

typedef struct
{
    uint8_t data[STRING_SIZE];
} String;

// Enums.

typedef enum
{
    PROPERTY_HINT_NONE = 0,
} PropertyHint;

typedef enum
{
    PROPERTY_USAGE_NONE = 0,
    PROPERTY_USAGE_STORAGE = 2,
    PROPERTY_USAGE_EDITOR = 4,
    PROPERTY_USAGE_DEFAULT = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
} PropertyUsageFlags;

While it's the same size as StringName, it is more clear to use a different name for it.

The enums here are just helpers to give names to the numbers they represent. The information about them is present in the extension_api.json file. Here we just set up the ones we need for the tutorial, to keep it more concise.

Going now to the api.c, we need to load the pointers to the new functions we added to the API.

void load_api(GDExtensionInterfaceGetProcAddress p_get_proc_address)
{
    ...
    // API
    ...
    api.classdb_register_extension_class_method = p_get_proc_address("classdb_register_extension_class_method");

    // Constructors.
    ...
    constructors.string_new_with_utf8_chars = p_get_proc_address("string_new_with_utf8_chars");

    // Destructors.
    ...
    destructors.string_destructor = variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
}

Then we can also implement the functions to create the PropertyInfo struct.

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
    constructors.string_name_new_with_latin1_chars(prop_name, name, false);
    String *prop_hint_string = api.mem_alloc(sizeof(String));
    constructors.string_new_with_utf8_chars(prop_hint_string, hint_string);
    StringName *prop_class_name = api.mem_alloc(sizeof(StringName));
    constructors.string_name_new_with_latin1_chars(prop_class_name, class_name, false);

    GDExtensionPropertyInfo info = {
        .name = prop_name,
        .type = type,
        .hint = hint,
        .hint_string = prop_hint_string,
        .class_name = prop_class_name,
        .usage = usage_flags,
    };

    return info;
}

void destruct_property(GDExtensionPropertyInfo *info)
{
    destructors.string_name_destructor(info->name);
    destructors.string_destructor(info->hint_string);
    destructors.string_name_destructor(info->class_name);
    api.mem_free(info->name);
    api.mem_free(info->hint_string);
    api.mem_free(info->class_name);
}

The simple version of make_property() just calls the more complete one with a some default arguments. What those values mean exactly is out of the scope of this tutorial, check the page about the Object class for more details about binding methods and properties.

The complete version is more involved. First, it creates String's and StringName's for the needed fields, by allocating memory and calling their constructors. Then it creates a GDExtensionPropertyInfo struct and sets all the fields with the arguments provided. Finally it returns this created struct.

The destruct_property() function is straightforward, it simply calls the destructors for the created objects and frees their allocated memory.

Let's go back again to the header api.h to create the functions that will actually bind the methods:

// Version for 0 arguments, with return.
void bind_method_0_r(
    const char *class_name,
    const char *method_name,
    void *function,
    GDExtensionVariantType return_type);

// Version for 1 argument, no return.
void bind_method_1(
    const char *class_name,
    const char *method_name,
    void *function,
    const char *arg1_name,
    GDExtensionVariantType arg1_type);

Then switch back to the api.c file to implement these:

// Version for 0 arguments, with return.
void bind_method_0_r(
    const char *class_name,
    const char *method_name,
    void *function,
    GDExtensionVariantType return_type)
{
    StringName method_name_string;
    constructors.string_name_new_with_latin1_chars(&method_name_string, method_name, false);

    GDExtensionClassMethodCall call_func = call_0_args_ret_float;
    GDExtensionClassMethodPtrCall ptrcall_func = ptrcall_0_args_ret_float;

    GDExtensionPropertyInfo return_info = make_property(return_type, "");

    GDExtensionClassMethodInfo method_info = {
        .name = &method_name_string,
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
    constructors.string_name_new_with_latin1_chars(&class_name_string, class_name, false);

    api.classdb_register_extension_class_method(class_library, &class_name_string, &method_info);

    // Destruct things.
    destructors.string_name_destructor(&method_name_string);
    destructors.string_name_destructor(&class_name_string);
    destruct_property(&return_info);
}

// Version for 1 argument, no return.
void bind_method_1(
    const char *class_name,
    const char *method_name,
    void *function,
    const char *arg1_name,
    GDExtensionVariantType arg1_type)
{

    StringName method_name_string;
    constructors.string_name_new_with_latin1_chars(&method_name_string, method_name, false);

    GDExtensionClassMethodCall call_func = call_1_float_arg_no_ret;
    GDExtensionClassMethodPtrCall ptrcall_func = ptrcall_1_float_arg_no_ret;

    GDExtensionPropertyInfo args_info[] = {
        make_property(arg1_type, arg1_name),
    };
    GDExtensionClassMethodArgumentMetadata args_metadata[] = {
        GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
    };

    GDExtensionClassMethodInfo method_info = {
        .name = &method_name_string,
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
    constructors.string_name_new_with_latin1_chars(&class_name_string, class_name, false);

    api.classdb_register_extension_class_method(class_library, &class_name_string, &method_info);

    // Destruct things.
    destructors.string_name_destructor(&method_name_string);
    destructors.string_name_destructor(&class_name_string);
    destruct_property(&args_info[0]);
}

Both functions are very similar. First, they create a StringName with the method name. This is created in the stack since we don't need to keep it after the function ends. Then they create local variables to hold the call_func and ptrcall_func, pointing to the helper functions we defined earlier.

In the next step they diverge a bit. The first one creates a property for the return value, which has an empty name since it's not needed. The other creates an array of properties for the arguments, which in this case has a single element. This one also has an array of metadata, which can be used if there's something special about the argument (e.g. if an int value is 32 bits long instead of the default of 64 bits).

Afterwards, they create the GDExtensionClassMethodInfo with the required fields for each case. Then they make a StringName for the class name, in order to associate the method with the class. Next, they call the API function to actually bind this method to the class. Finally, we destruct the objects we created since they aren't needed anymore.

Note

The bind helpers here use the call helpers we created earlier, so do note that those call helpers only accept the Godot FLOAT type (which is equivalent to double in C). If you intend to use this for other types, you would need to check the type of the arguments and return type and select an appropriate function callback. This is avoided here only to keep the example from becoming even longer.

Now that we have the means to bind methods, we can actually do so in our custom class. Go to the gdexample.c file and fill up the gdexample_class_bind_methods() function:

void gdexample_class_bind_methods()
{
    bind_method_0_r("GDExample", "get_amplitude", gdexample_class_get_amplitude, GDEXTENSION_VARIANT_TYPE_FLOAT);
    bind_method_1("GDExample", "set_amplitude", gdexample_class_set_amplitude, "amplitude", GDEXTENSION_VARIANT_TYPE_FLOAT);

    bind_method_0_r("GDExample", "get_speed", gdexample_class_get_speed, GDEXTENSION_VARIANT_TYPE_FLOAT);
    bind_method_1("GDExample", "set_speed", gdexample_class_set_speed, "speed", GDEXTENSION_VARIANT_TYPE_FLOAT);
}

Since this function is already being called by the initialization process, we can stop here. This function is much more straightforward after we created all the infrastructure to make this work. You can see that implementing the binding functions inline here would take some space and also be quite repetitive. This also makes it easier to add another method in the future.

If you compile the code and reopen the demo project, nothing will be different at first, since we only added two new methods. To ensure those are registered properly, you can search for GDExample in the editor help and verify they are present in the documentation page.