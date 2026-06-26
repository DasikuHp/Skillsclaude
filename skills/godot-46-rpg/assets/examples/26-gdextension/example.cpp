#include "example.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void Example::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_speed", "speed"), &Example::set_speed);
    ClassDB::bind_method(D_METHOD("get_speed"), &Example::get_speed);
    ClassDB::bind_method(D_METHOD("sum_hot_loop", "data"), &Example::sum_hot_loop);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed"), "set_speed", "get_speed");
}

void Example::_process(double delta) {
    // hot loop nativo aqui
}

void Example::set_speed(double p_speed) {
    speed = p_speed;
}

double Example::get_speed() const {
    return speed;
}

int64_t Example::sum_hot_loop(const PackedInt32Array &p_data) const {
    int64_t acc = 0;
    const int32_t *ptr = p_data.ptr();        // puntero directo, sin copiar
    const int64_t n = p_data.size();
    for (int64_t i = 0; i < n; ++i) {
        acc += ptr[i];
    }
    return acc;
}
