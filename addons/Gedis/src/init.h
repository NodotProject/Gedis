#ifndef INIT_H
#define INIT_H

#include "defs.h"

#include "gdextension_interface.h"

void initialize_gedis_module(void *p_userdata, GDExtensionInitializationLevel p_level);
void deinitialize_gedis_module(void *p_userdata, GDExtensionInitializationLevel p_level);
GDExtensionBool GDE_EXPORT gedis_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization);

#endif // INIT_H
