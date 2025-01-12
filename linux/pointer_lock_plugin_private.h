#include <flutter_linux/flutter_linux.h>

#include "include/pointer_lock/pointer_lock_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

FlMethodResponse* pointer_position_on_screen(const PointerLockPlugin* plugin);
FlMethodResponse* last_pointer_delta(const PointerLockPlugin* plugin);
FlMethodResponse* set_pointer_visible(PointerLockPlugin* plugin, bool visible);
FlMethodResponse* set_pointer_locked(PointerLockPlugin* plugin, bool locked);