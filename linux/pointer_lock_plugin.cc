#include "include/pointer_lock/pointer_lock_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "pointer_lock_plugin_private.h"

#define POINTER_LOCK_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), pointer_lock_plugin_get_type(), \
                              PointerLockPlugin))

struct _PointerLockPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
};

G_DEFINE_TYPE(PointerLockPlugin, pointer_lock_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void pointer_lock_plugin_handle_method_call(
    PointerLockPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "pointerPositionOnScreen") == 0) {
    response = pointer_position_on_screen(self->registrar);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* pointer_position_on_screen(FlPluginRegistrar* registrar) {
  FlView* view = fl_plugin_registrar_get_view(registrar);
  if (!view) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("No screen", nullptr, nullptr));
  }
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(window));
  if (!display) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("No display", nullptr, nullptr));
  }
  GdkSeat *seat = gdk_display_get_default_seat(display);
  if (!seat) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("No seat", nullptr, nullptr));
  }
  GdkDevice *pointer = gdk_seat_get_pointer(seat);
  if (!pointer) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("No pointer", nullptr, nullptr));
  }
  int x, y;
  gdk_device_get_position(pointer, nullptr, &x, &y);

  g_autoptr(FlValue) result = fl_value_new_float_list((double[]){static_cast<double>(x), static_cast<double>(y)}, 2);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void pointer_lock_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(pointer_lock_plugin_parent_class)->dispose(object);
}

static void pointer_lock_plugin_class_init(PointerLockPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = pointer_lock_plugin_dispose;
}

static void pointer_lock_plugin_init(PointerLockPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  PointerLockPlugin* plugin = POINTER_LOCK_PLUGIN(user_data);
  pointer_lock_plugin_handle_method_call(plugin, method_call);
}

void pointer_lock_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  PointerLockPlugin* plugin = POINTER_LOCK_PLUGIN(
      g_object_new(pointer_lock_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "pointer_lock",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
