#include "include/pointer_lock/pointer_lock_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <gdk/gdkx.h>
// #include <gdk/gdkwayland.h>
// #include "include/pointer-constraints-unstable-v1-client-protocol.h"

#include "pointer_lock_plugin_private.h"

#define POINTER_LOCK_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), pointer_lock_plugin_get_type(), \
                              PointerLockPlugin))


// TODO-high CONTINUE Make members of plugin
double initial_x = 0.0;
double initial_y = 0.0;
double dx = 0.0;
double dy = 0.0;
gulong handler_id = 0;

struct _PointerLockPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
};

FlMethodResponse* error(const char* code) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, nullptr, nullptr));
}

FlMethodResponse* no_window_error() {
  return error("No window");
}

FlMethodResponse* no_pointer_error() {
  return error("No pointer");
}

GdkWindow* get_gdk_window(FlPluginRegistrar* registrar) {
  FlView* view = fl_plugin_registrar_get_view(registrar);
  if (!view) {
    return nullptr;
  }
  return gtk_widget_get_window(GTK_WIDGET(view));
}

GtkWindow* get_gtk_window(FlPluginRegistrar* registrar) {
  FlView* view = fl_plugin_registrar_get_view(registrar);
  if (!view) {
    return nullptr;
  }
  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

G_DEFINE_TYPE(PointerLockPlugin, pointer_lock_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void pointer_lock_plugin_handle_method_call(
    const PointerLockPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "hidePointer") == 0) {
    response = set_show_pointer(self, false);
  } else if (strcmp(method, "showPointer") == 0) {
    response = set_show_pointer(self, true);
  } else if (strcmp(method, "lockPointer") == 0) {
    response = set_lock_pointer(self, true);
  } else if (strcmp(method, "unlockPointer") == 0) {
    response = set_lock_pointer(self, false);
  } else if (strcmp(method, "subscribeToRawInputData") == 0) {
    response = set_subscribe_to_raw_input_data(self, true);
  } else if (strcmp(method, "unsubscribeFromRawInputData") == 0) {
    response = set_subscribe_to_raw_input_data(self, false);
  } else if (strcmp(method, "lastPointerDelta") == 0) {
    response = last_pointer_delta(self);
  } else if (strcmp(method, "pointerPositionOnScreen") == 0) {
    response = pointer_position_on_screen(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* success_response() {
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* point_response(const double x, const double y) {
  g_autoptr(FlValue) result = fl_value_new_float_list((double[]){x, y},2);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* pointer_position_on_screen(const PointerLockPlugin* plugin) {
  GdkWindow* window = get_gdk_window(plugin->registrar);
  if (!window) {
    return no_window_error();
  }
  GdkDisplay *display = gdk_window_get_display(window);
  GdkSeat *seat = gdk_display_get_default_seat(display);
  GdkDevice *pointer = gdk_seat_get_pointer(seat);
  if (!pointer) {
    return no_pointer_error();
  }
  int x, y;
  gdk_device_get_position(pointer, nullptr, &x, &y);

  // WARP TEST
  // auto dest_window = GDK_WINDOW_XID(window);
  // XWarpPointer(GDK_DISPLAY_XDISPLAY(display), None, dest_window, 0, 0, 0, 0, 0, 0);
  return point_response(x, y);
}

FlMethodResponse* last_pointer_delta(const PointerLockPlugin* plugin) {
  // GdkWindow* window = get_gdk_window(plugin->registrar);
  // if (!window) {
  //   return no_window_error();
  // }
  // GdkDisplay *display = gdk_window_get_display(window);
  //// WARP TEST
  // auto dest_window = GDK_WINDOW_XID(window);
  // XWarpPointer(GDK_DISPLAY_XDISPLAY(display), None, dest_window, 0, 0, 0, 0, 0, 0);

  return point_response(dx, dy);
}

FlMethodResponse* set_show_pointer(const PointerLockPlugin* plugin, bool show) {
  GdkWindow* window = get_gdk_window(plugin->registrar);
  if (!window) {
    return no_window_error();
  }
  GdkDisplay *display = gdk_window_get_display(window);
  if (show) {
    gdk_window_set_cursor(window, nullptr);
  } else {
    GdkCursor *invisible_cursor = gdk_cursor_new_for_display(display, GDK_BLANK_CURSOR);
    gdk_window_set_cursor(window, invisible_cursor);
    g_object_unref(invisible_cursor);
  }
  return success_response();
}

// FlMethodResponse* set_lock_pointer(const PointerLockPlugin* plugin, bool lock) {
//   set_subscribe_to_raw_input_data(plugin, lock);
//   GdkWindow* window = get_gdk_window(plugin->registrar);
//   if (!window) {
//     return no_window_error();
//   }
//   GdkDisplay *display = gdk_window_get_display(window);
//   GdkSeat *seat = gdk_display_get_default_seat(display);
//   GdkDevice *pointer = gdk_seat_get_pointer(seat);
//   if (!pointer) {
//     return no_pointer_error();
//   }
//   if (lock) {
//     int x, y;
//     gdk_device_get_position(pointer, nullptr, &x, &y);
//     initial_x = static_cast<double>(x);
//     initial_y = static_cast<double>(y);
//     GdkCursor *invisible_cursor = gdk_cursor_new_for_display(display, GDK_BLANK_CURSOR);
//     GdkCursor *cursor = nullptr;
//     bool owner_events = TRUE;
//     GdkGrabStatus status = gdk_seat_grab(seat, window, GDK_SEAT_CAPABILITY_ALL_POINTING, owner_events, cursor, nullptr, nullptr, nullptr);
//     g_object_unref(invisible_cursor);
//     if (status != GDK_GRAB_SUCCESS) {
//       return error("Failed to grab seat");
//     }
//   } else {
//     gdk_seat_ungrab(seat);
//   }
//   return success_response();
// }

FlMethodResponse* set_lock_pointer(const PointerLockPlugin* plugin, bool lock) {
    set_subscribe_to_raw_input_data(plugin, lock);
    FlView* view = fl_plugin_registrar_get_view(plugin->registrar);
    GtkWindow* gtk_window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
    auto* display = gtk_widget_get_display(GTK_WIDGET(gtk_window));
    auto* xDisplay = GDK_DISPLAY_XDISPLAY(display);
    if (lock) {
      GdkCursor *invisible_cursor = gdk_cursor_new_for_display(display, GDK_X_CURSOR);
      auto window = GDK_WINDOW_XID(gtk_widget_get_window(GTK_WIDGET(gtk_window)));
      auto xCursor = gdk_x11_cursor_get_xcursor(invisible_cursor);
      int eventMask = PointerMotionMask | ButtonReleaseMask | ButtonPressMask | EnterWindowMask | LeaveWindowMask;
      XUngrabPointer(xDisplay, 0);
      // If TRUE, the window will still receive and process events, causing below g_signal_connect to not
      // obtain mouse events happening over the Flutter view, because Flutter's GTK handlers stop propagating
      // the events. It will only receive mouse events happening over the window title bar.
      // We don't want the Flutter view to process movement events anyway. It will cause weird hover
      // events and stuff.
      //
      // If FALSE, the window will not receive any events, causing g_signal_connect to not
      // obtain any events. I think this is the way. But We need to find a way to actually get hold of the events.
      bool owner_events = TRUE;
      auto result = XGrabPointer(xDisplay, window, owner_events, eventMask, GrabModeAsync, GrabModeAsync, window, xCursor, 0);
      g_object_unref(invisible_cursor);
      if (result != GrabSuccess) {
        return error("XGrabPointer failed");
      }
      // XEvent event;
      // while (1) {
      //   XNextEvent(xDisplay, &event);
      //   g_print("e\n");
      // }
    } else {
      XUngrabPointer(xDisplay, 0);
    }
    return success_response();
}

static gboolean on_motion_notify(GtkWidget *widget, GdkEventMotion *event, gpointer data) {
  static double last_x = 0;
  static double last_y = 0;
  dx = event->x - last_x;
  dy = event->y - last_y;
  last_x = event->x;
  last_y = event->y;

  // Actual
  // if (dx == 0 && dy == 0) {
  //   return GDK_EVENT_STOP;
  // }
  g_print("Mouse delta: dx=%.2f, dy=%.2f\n", dx, dy);
  auto* display = GDK_DISPLAY_XDISPLAY(gtk_widget_get_display(widget));
  auto window = GDK_WINDOW_XID(gtk_widget_get_window(widget));
  // float scaleFactor = m_webPage.deviceScaleFactor();
  // IntSize warp = delta;
  // warp.scale(-scaleFactor);
  if (!display) {
    g_print("couldn't get X display");
    return GDK_EVENT_STOP;
  }
  int warp_x = 0;
  int warp_y = 0;
  // Reminder: When running Linux in a VM, this only works if capturing is enabled!
  XWarpPointer(display, None, window, 0, 0, 0, 0, warp_x, warp_y);

  return GDK_EVENT_STOP;
}

FlMethodResponse* set_subscribe_to_raw_input_data(const PointerLockPlugin* plugin, bool subscribe) {
  FlView* view = fl_plugin_registrar_get_view(plugin->registrar);
  if (!view) {
    return no_window_error();
  }
  if (subscribe && handler_id == 0) {
    g_print("connect\n");
    GtkWindow* gtk_window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
    // GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(view));
    //
    // This can be called with gtk_window or with view (both widgets). Both reach the title bar only because
    // Flutter consumes the events already.
    gtk_widget_add_events(GTK_WIDGET(gtk_window), GDK_POINTER_MOTION_MASK);

    // This can be called with gtk_window (works) and view (doesn't work).
    handler_id = g_signal_connect(gtk_window, "motion-notify-event", G_CALLBACK(on_motion_notify), NULL);

    if (handler_id == 0) {
      return error("g_signal_connect failed");
    }
  } else if (handler_id != 0) {
    g_print("disconnect\n");
    g_signal_handler_disconnect(view, handler_id);
    handler_id = 0;
  }
  return success_response();
}

// FlMethodResponse* set_subscribe_to_raw_input_data(const PointerLockPlugin* plugin, bool subscribe) {
//   FlView* view = fl_plugin_registrar_get_view(plugin->registrar);
//   if (!view) {
//     return no_window_error();
//   }
//   if (subscribe && handler_id == 0) {
//     g_print("connect\n");
//     GtkWidget* event_box = gtk_event_box_new();
//     gtk_widget_set_hexpand(event_box, TRUE);
//     gtk_widget_set_vexpand(event_box, TRUE);
//     // gtk_widget_set_hexpand(GTK_WIDGET(view), TRUE);
//     // gtk_widget_set_vexpand(GTK_WIDGET(view), TRUE);
//     // gtk_widget_set_halign(event_box, GTK_ALIGN_FILL);
//     // gtk_widget_set_valign(event_box, GTK_ALIGN_FILL);
//     gtk_container_add(GTK_CONTAINER(view), event_box);
//     gtk_widget_show(event_box);
//     gtk_event_box_set_visible_window(GTK_EVENT_BOX(event_box), FALSE);
//     gtk_widget_add_events(event_box,
//                           GDK_POINTER_MOTION_MASK | GDK_BUTTON_PRESS_MASK |
//                               GDK_BUTTON_RELEASE_MASK | GDK_SCROLL_MASK |
//                               GDK_SMOOTH_SCROLL_MASK | GDK_TOUCH_MASK);
//     g_signal_connect(event_box, "motion-notify-event",
//                              G_CALLBACK(on_motion_notify), NULL);
//
//
//     if (handler_id == 0) {
//       return error("g_signal_connect failed");
//     }
//   } else if (handler_id != 0) {
//     g_print("disconnect\n");
//     g_signal_handler_disconnect(view, handler_id);
//     handler_id = 0;
//   }
//   return success_response();
// }

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

// bool PointerLockManagerX11::lock()
// {
//   if (!PointerLockManager::lock())
//     return false;
//
//   auto* viewWidget = m_webPage.viewWidget();
//   auto* display = gtk_widget_get_display(viewWidget);
//   auto* xDisplay = GDK_DISPLAY_XDISPLAY(gtk_widget_get_display(viewWidget));
// #if USE(GTK4)
//   GRefPtr<GdkCursor> cursor = adoptGRef(gdk_cursor_new_from_name("none", nullptr));
//   auto window = GDK_SURFACE_XID(gtk_native_get_surface(gtk_widget_get_native(viewWidget)));
//   auto xCursor = gdk_x11_display_get_xcursor(display, cursor.get());
// #else
//   GRefPtr<GdkCursor> cursor = adoptGRef(gdk_cursor_new_from_name(display, "none"));
//   auto window = GDK_WINDOW_XID(gtk_widget_get_window(viewWidget));
//   auto xCursor = gdk_x11_cursor_get_xcursor(cursor.get());
// #endif
//   int eventMask = PointerMotionMask | ButtonReleaseMask | ButtonPressMask | EnterWindowMask | LeaveWindowMask;
//   XUngrabPointer(xDisplay, 0);
//   return XGrabPointer(xDisplay, window, true, eventMask, GrabModeAsync, GrabModeAsync, window, xCursor, 0) == GrabSuccess;
// }
//
// bool PointerLockManagerX11::unlock()
// {
//   if (m_device)
//     XUngrabPointer(GDK_DISPLAY_XDISPLAY(gtk_widget_get_display(m_webPage.viewWidget())), 0);
//
//   return PointerLockManager::unlock();
// }
//
// void PointerLockManagerX11::didReceiveMotionEvent(const FloatPoint& point)
// {
//   auto delta = IntSize(point - m_initialPoint);
//   if (delta.isZero())
//     return;
//
//   handleMotion(delta);
//   auto* display = GDK_DISPLAY_XDISPLAY(gtk_widget_get_display(m_webPage.viewWidget()));
//   float scaleFactor = m_webPage.deviceScaleFactor();
//   IntSize warp = delta;
//   warp.scale(-scaleFactor);
//   XWarpPointer(display, None, None, 0, 0, 0, 0, warp.width(), warp.height());
// }
//
// } // namespace WebKit