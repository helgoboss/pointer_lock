#include "include/pointer_lock/pointer_lock_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
// #include <gdk/gdkx.h>

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

GdkPoint get_pointer_position_on_screen(GdkDisplay* gdk_display) {
  GdkSeat* gdk_seat = gdk_display_get_default_seat(gdk_display);
  GdkDevice* gdk_pointer = gdk_seat_get_pointer(gdk_seat);
  if (!gdk_pointer) {
    return {0, 0};
  }
  int x, y;
  gdk_device_get_position(gdk_pointer, nullptr, &x, &y);
  return {x, y};
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
  GdkPoint pos = get_pointer_position_on_screen(gdk_display);
  return point_response(pos.x, pos.y);
}

FlMethodResponse* last_pointer_delta(const PointerLockPlugin* plugin) {
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  if (!gdk_window) {
    return no_window_error_response();
  }
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  GdkPoint new_pointer_pos = get_pointer_position_on_screen(gdk_display);
  GdkScreen *gdk_screen = gdk_display_get_default_screen(gdk_display);
  GdkSeat *gdk_seat = gdk_display_get_default_seat(gdk_display);
  GdkDevice *gdk_pointer = gdk_seat_get_pointer(gdk_seat);
  int initial_x = plugin->initial_pointer_pos.x;
  int initial_y = plugin->initial_pointer_pos.y;
  gdk_device_warp(gdk_pointer, gdk_screen, initial_x, initial_y);
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
    GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
    GdkCursor* gdk_cursor = gdk_cursor_new_for_display(gdk_display, GDK_BLANK_CURSOR);
    gdk_window_set_cursor(gdk_window, gdk_cursor);
    g_object_unref(gdk_cursor);
  }
  return success_response();
}

FlMethodResponse* set_pointer_locked(PointerLockPlugin* plugin, bool locked) {
  GdkWindow* gdk_window = get_gdk_window(plugin->registrar);
  if (!gdk_window) {
    return no_window_error_response();
  }
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
  GdkSeat *gdk_seat = gdk_display_get_default_seat(gdk_display);
  if (locked) {
    // Memorize initial pointer position
    plugin->initial_pointer_pos = get_pointer_position_on_screen(gdk_display);
    // Grab pointer
    gdk_seat_ungrab(gdk_seat);
    // Always use blank cursor! Otherwise, the warping won't work (at least not on Wayland).
    GdkCursor* gdk_cursor = gdk_cursor_new_for_display(gdk_display, GDK_BLANK_CURSOR);
    // gdk_seat_grab is the replacement of the deprecated gdk_pointer_grab, but unfortunately it doesn't allow
    // confining the cursor to the window. Very fast mouse movements will make the cursor end up outside the window,
    // and then warping to the original position is not possible anymore (at least on Wayland). This could
    // maybe be avoided by *synchronously* warping on pointer move events. At the moment we warp asynchronously:
    // Mouse movement => Native code calls Dart code => Dart code requests last pointer delta => Native code warps.
    // I don't know how to get synchronously informed of mouse events on the native side without hacking the
    // Flutter Engine.
    // GdkGrabStatus result = gdk_seat_grab(gdk_seat, gdk_window, GDK_SEAT_CAPABILITY_ALL_POINTING, TRUE, gdk_cursor, nullptr, nullptr, nullptr);
    auto gdk_event_mask = static_cast<GdkEventMask>(GDK_POINTER_MOTION_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK);
    // Use deprecated gdk_pointer_grab in order to confine to a window.
    GdkGrabStatus result = gdk_pointer_grab(gdk_window, TRUE, gdk_event_mask, gdk_window, gdk_cursor, GDK_CURRENT_TIME);
    g_object_unref(gdk_cursor);
    if (result != GDK_GRAB_SUCCESS) {
      return error_response("gdk_seat_grab failed");
    }
  } else {
    gdk_seat_ungrab(gdk_seat);
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

  g_object_unref(plugin);
}