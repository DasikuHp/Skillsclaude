#include "register_types.h"
#include "example.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_example_module(ModuleInitializationLevel p_level) {
    // CRITICO: para Node/Resource registra en SCENE; otro nivel = clase invisible
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    GDREGISTER_CLASS(Example);
    // GDREGISTER_ABSTRACT_CLASS(Base);   // base no instanciable
    // GDREGISTER_VIRTUAL_CLASS(Iface);   // solo interfaz
}

void uninitialize_example_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
// El nombre DEBE ser identico a entry_symbol del .gdextension
GDExtensionBool GDE_EXPORT example_library_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(
            p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_example_module);
    init_obj.register_terminator(uninitialize_example_module);
    init_obj.set_minimum_library_initialization_level(
            MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
