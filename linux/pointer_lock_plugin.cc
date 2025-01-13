#include "include/pointer_lock/pointer_lock_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <gdk/gdkx.h>
#include <gdk/gdkwayland.h>
#include "include/pointer-constraints-unstable-v1-client-protocol.h"

#include "pointer_lock_plugin_private.h"

#define POINTER_LOCK_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), pointer_lock_plugin_get_type(), \
                              PointerLockPlugin))

struct _PointerLockPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  GdkPoint initial_pointer_pos;
  bool cursor_visible;
};

static FlEventChannel *event_channel = nullptr;

// Reusable functions

GdkWindow* get_gdk_window(FlPluginRegistrar* registrar) {
  FlView* fl_view = fl_plugin_registrar_get_view(registrar);
  if (!fl_view) {
    return nullptr;
  }
  return gtk_widget_get_window(GTK_WIDGET(fl_view));
}

FlMethodResponse* success_response() {
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlValue* point_value(const double x, const double y) {
  return fl_value_new_float_list((double[]){x, y}, 2);
}

FlMethodResponse* point_response(const double x, const double y) {
  g_autoptr(FlValue) result = point_value(x, y);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* error_response(const char* code) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, nullptr, nullptr));
}

FlMethodResponse* no_window_error_response() {
  return error_response("No window");
}

FlMethodResponse* no_pointer_error_response() {
  return error_response("No pointer");
}

GdkPoint get_pointer_pos_relative_to_window(GdkWindow* gdk_window) {
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  Window x_window = GDK_WINDOW_XID(gdk_window);
  Display* x_display = GDK_DISPLAY_XDISPLAY(gdk_display);
  Window root_x_window = DefaultRootWindow(x_display);
  Window child_x_window = root_x_window;
  int root_x, root_y, win_x, win_y = 0;
  unsigned int mask = 0;
  Bool success = XQueryPointer(x_display, x_window, &root_x_window,
                               &child_x_window,
                               &root_x, &root_y, &win_x, &win_y, &mask);
  if (!success) {
    g_printerr("XQueryPointer failed\n");
  }
  return {win_x, win_y};
}

// End reusable functions

G_DEFINE_TYPE(PointerLockPlugin, pointer_lock_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void pointer_lock_plugin_handle_method_call(
    PointerLockPlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "flutterRestart") == 0) {
    set_pointer_visible(self, true);
    set_pointer_locked(self, false);
    response = success_response();
  } else if (strcmp(method, "hidePointer") == 0) {
    response = set_pointer_visible(self, false);
  } else if (strcmp(method, "showPointer") == 0) {
    response = set_pointer_visible(self, true);
  } else if (strcmp(method, "lockPointer") == 0) {
    response = set_pointer_locked(self, true);
  } else if (strcmp(method, "unlockPointer") == 0) {
    response = set_pointer_locked(self, false);
  } else if (strcmp(method, "lastPointerDelta") == 0) {
    response = last_pointer_delta(self);
  } else if (strcmp(method, "pointerPositionOnScreen") == 0) {
    response = pointer_position_on_screen(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* pointer_position_on_screen(const PointerLockPlugin* plugin) {
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  if (!gdk_window) {
    return no_window_error_response();
  }
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  GdkSeat* gdk_seat = gdk_display_get_default_seat(gdk_display);
  GdkDevice* gdk_pointer = gdk_seat_get_pointer(gdk_seat);
  if (!gdk_pointer) {
    return no_pointer_error_response();
  }
  int x, y;
  gdk_device_get_position(gdk_pointer, nullptr, &x, &y);
  return point_response(x, y);
}

FlMethodResponse* last_pointer_delta(const PointerLockPlugin* plugin) {
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  if (!gdk_window) {
    return no_window_error_response();
  }
  GdkPoint new_pointer_pos = get_pointer_pos_relative_to_window(gdk_window);
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  Display* x_display = GDK_DISPLAY_XDISPLAY(gdk_display);
  Window x_window = GDK_WINDOW_XID(gdk_window);
  int initial_x = plugin->initial_pointer_pos.x;
  int initial_y = plugin->initial_pointer_pos.y;
  XWarpPointer(x_display, None, x_window, 0, 0, 0, 0, initial_x, initial_y);
  return point_response(new_pointer_pos.x - initial_x,
                        new_pointer_pos.y - initial_y);
}

FlMethodResponse* set_pointer_visible(PointerLockPlugin* plugin, bool visible) {
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  if (!gdk_window) {
    return no_window_error_response();
  }
  plugin->cursor_visible = visible;
  if (visible) {
    gdk_window_set_cursor(gdk_window, nullptr);
  } else {
    GdkDisplay* display = gdk_window_get_display(gdk_window);
    GdkCursor* invisible_cursor = gdk_cursor_new_for_display(
        display, GDK_BLANK_CURSOR);
    gdk_window_set_cursor(gdk_window, invisible_cursor);
    g_object_unref(invisible_cursor);
  }
  return success_response();
}

FlMethodResponse* set_pointer_locked(PointerLockPlugin* plugin, bool locked) {
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  Display* x_display = GDK_DISPLAY_XDISPLAY(gdk_display);
  if (!gdk_window) {
    return no_window_error_response();
  }
  if (locked) {
    // Memorize initial pointer position
    plugin->initial_pointer_pos =
        get_pointer_pos_relative_to_window(gdk_window);
    // Grab pointer
    Window x_window = GDK_WINDOW_XID(gdk_window);
    // Somehow, only the blank cursor works with XWarpPointer (which keeps the pointer at its place), at
    // least when running on Wayland. No problem. Ignore the cursor hint. Just always hide the cursor.
    GdkCursor* gdk_cursor = gdk_cursor_new_for_display(gdk_display, GDK_BLANK_CURSOR);
    Cursor x_cursor = gdk_cursor ? gdk_x11_cursor_get_xcursor(gdk_cursor) : 0;
    int eventMask =
        PointerMotionMask | ButtonReleaseMask | ButtonPressMask |
        EnterWindowMask | LeaveWindowMask;
    XUngrabPointer(x_display, 0);
    int result = XGrabPointer(x_display, x_window, TRUE, eventMask,
                              GrabModeAsync, GrabModeAsync, x_window,
                              x_cursor, 0);
    if (gdk_cursor) {
      g_object_unref(gdk_cursor);
    }
    if (result != GrabSuccess) {
      return error_response("XGrabPointer failed");
    }
  } else {
    XUngrabPointer(x_display, 0);
  }
  return success_response();
}

static void pointer_lock_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(pointer_lock_plugin_parent_class)->dispose(object);
}

static void pointer_lock_plugin_class_init(PointerLockPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = pointer_lock_plugin_dispose;
}

static void pointer_lock_plugin_init(PointerLockPlugin* self) {
  self->cursor_visible = true;
  self->initial_pointer_pos.x = 0;
  self->initial_pointer_pos.y = 0;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  PointerLockPlugin* plugin = POINTER_LOCK_PLUGIN(user_data);
  pointer_lock_plugin_handle_method_call(plugin, method_call);
}


// WAYLAND EXPERIMENTS - BEGIN (not in use!)

struct zwp_pointer_constraints_v1 *pointer_constraints = NULL;


wl_surface* get_wayland_surface(GdkWindow *gdk_window) {
  // Ensure we are running under Wayland
  if (GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    wl_surface* surface = gdk_wayland_window_get_wl_surface(gdk_window);
    if (!surface) {
      g_warning("Failed to get wl_surface");
    }
    return surface;
  } else {
    g_warning("Not running under Wayland backend");
    return nullptr;
  }
}


static void locked_pointer_locked(void *data, struct zwp_locked_pointer_v1 *locked_pointer) {
  printf("Pointer locked\n");
}

static void locked_pointer_unlocked(void *data, struct zwp_locked_pointer_v1 *locked_pointer) {
  printf("Pointer unlocked\n");
}

static const struct zwp_locked_pointer_v1_listener locked_pointer_listener = {
  .locked = locked_pointer_locked,
  .unlocked = locked_pointer_unlocked,
};

static FlMethodErrorResponse* listen_cb (FlEventChannel* channel,
                                         FlValue *args,
                                         gpointer user_data) {
  PointerLockPlugin* plugin = static_cast<PointerLockPlugin*>(user_data);
  // TODO complain if window null
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  // TODO complain if not wayland
    GdkSeat *gdk_seat = gdk_display_get_default_seat(gdk_display);
  wl_surface* surface = get_wayland_surface(gdk_window);
  // TODO complain if null
  wl_seat* wayland_seat = gdk_wayland_seat_get_wl_seat(gdk_seat);
  struct wl_pointer *wayland_pointer = wl_seat_get_pointer(wayland_seat);

  if (!surface || !wayland_pointer) {
    fprintf(stderr, "Failed to create surface or pointer\n");
    return nullptr;
  }
  // Lock the pointer
  struct zwp_locked_pointer_v1 *locked_pointer =
      zwp_pointer_constraints_v1_lock_pointer(pointer_constraints, surface, wayland_pointer, nullptr, ZWP_POINTER_CONSTRAINTS_V1_LIFETIME_PERSISTENT);

  if (!locked_pointer) {
    fprintf(stderr, "Failed to lock pointer\n");
    return nullptr;
  }

  zwp_locked_pointer_v1_add_listener(locked_pointer, &locked_pointer_listener, NULL);


  g_autoptr(FlValue) value = point_value(5.0, 7.0);
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send (event_channel, value, nullptr, &error)) {
    g_warning ("Failed to send event: %s", error->message);
  }
  return nullptr;
}

static FlMethodErrorResponse* cancel_cb (FlEventChannel* channel,
                                         FlValue *args,
                                         gpointer user_data) {
  // set_pointer_locked(static_cast<PointerLockPlugin*>(user_data), true);
  return nullptr;
}

// WAYLAND EXPERIMENTS - END

void pointer_lock_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  // Initialize plugin
  PointerLockPlugin* plugin = POINTER_LOCK_PLUGIN(
      g_object_new(pointer_lock_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  // Set up channels
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  // Set up method channel
  g_autoptr(FlMethodChannel) method_channel =
      fl_method_channel_new(messenger,
                            "pointer_lock",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(method_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);
  // Set up event channel
  event_channel = fl_event_channel_new (messenger, "pointer_lock_session", FL_METHOD_CODEC (codec));
  fl_event_channel_set_stream_handlers (event_channel, listen_cb, cancel_cb,
                                       plugin, nullptr);

  g_object_unref(plugin);
}