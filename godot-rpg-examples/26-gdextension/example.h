#pragma once

#include <godot_cpp/classes/node3d.hpp>          // Node3D para un RPG 3D
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

class Example : public Node3D {
    GDCLASS(Example, Node3D)   // OBLIGATORIO, primer miembro; sin esto no registra

private:
    double speed = 1.0;

protected:
    static void _bind_methods();   // OBLIGATORIO; lo no bindeado es invisible en GDScript

public:
    Example() = default;
    ~Example() = default;

    void _process(double delta) override;   // virtual del motor: override, NO se bindea

    void set_speed(double p_speed);
    double get_speed() const;

    // hot loop nativo: acceso directo al buffer, sin overhead Variant
    int64_t sum_hot_loop(const PackedInt32Array &p_data) const;
};

} // namespace godot
