#include <flutter_linux/flutter_linux.h>

#include "include/pointer_lock/pointer_lock_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

FlMethodResponse *pointer_position_on_screen(const PointerLockPlugin* plugin);
FlMethodResponse *set_lock_pointer(const PointerLockPlugin* plugin, bool lock);
FlMethodResponse *set_show_pointer(const PointerLockPlugin* plugin, bool show);
FlMethodResponse *last_pointer_delta(const PointerLockPlugin* plugin);
FlMethodResponse *set_subscribe_to_raw_input_data(const PointerLockPlugin* plugin, bool subscribe);
