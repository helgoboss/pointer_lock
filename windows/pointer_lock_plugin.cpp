#include "pointer_lock_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <hidusage.h>
#include <windowsx.h>

namespace pointer_lock {

// static
void PointerLockPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), 
      "pointer_lock",
      &flutter::StandardMethodCodec::GetInstance()
  );
  auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
    registrar->messenger(),
    "pointer_lock_session",
    &flutter::StandardMethodCodec::GetInstance()
  );

  auto plugin = std::make_unique<PointerLockPlugin>(registrar);

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      }
  );
  event_channel->SetStreamHandler(std::make_unique<PointerLockSessionStreamHandler>(registrar));

  registrar->AddPlugin(std::move(plugin));
}

PointerLockPlugin::PointerLockPlugin(flutter::PluginRegistrarWindows* registrar) {
  registrar_ = registrar;
}

PointerLockPlugin::~PointerLockPlugin() {
  UnsubscribeFromRawInputData();
}

void PointerLockPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("lockPointer") == 0) {
    POINT cursor_pos;
    if (!GetCursorPos(&cursor_pos)) {
      result->Error("UNAVAILABLE", "Couldn't get current cursor position");
      return;
    }
    RECT rect{ cursor_pos.x, cursor_pos.y, cursor_pos.x, cursor_pos.y };
    ClipCursor(&rect);
    result->Success();
  } else if (method_call.method_name().compare("unlockPointer") == 0) {
    ClipCursor(NULL);
    result->Success();
  } else if (method_call.method_name().compare("hidePointer") == 0) {
    ShowCursor(0);
    result->Success();
  } else if (method_call.method_name().compare("showPointer") == 0) {
    ShowCursor(1);
    result->Success();
  } else if (method_call.method_name().compare("subscribeToRawInputData") == 0) {
    if (!SubscribeToRawInputData()) {
      result->Error("UNAVAILABLE", "Couldn't subscribe to raw input data");
      return;
    }
    result->Success();
  } else if (method_call.method_name().compare("lastPointerDelta") == 0) {
    if (!SubscribedToRawInputData()) {
      result->Error("ACTION_REQUIRED", "On Windows, you must call 'subscribeToRawInputData()' first.");
      return;
    }
    std::vector<double> vec{
      static_cast<double>(last_x_delta_),
      static_cast<double>(last_y_delta_)
    };
    result->Success(flutter::EncodableValue(std::move(vec)));
  } else {
    result->NotImplemented();
  }
}

bool PointerLockPlugin::SubscribeToRawInputData() {
  if (SubscribedToRawInputData()) {
    return true;
  }
  // Register raw input device
  RAWINPUTDEVICE Rid[1];
  Rid[0].usUsagePage = HID_USAGE_PAGE_GENERIC;
  Rid[0].usUsage = HID_USAGE_GENERIC_MOUSE;
  Rid[0].dwFlags = RIDEV_INPUTSINK;
  Rid[0].hwndTarget = GetParent(registrar_->GetView()->GetNativeWindow());
  if (!RegisterRawInputDevices(Rid, 1, sizeof(Rid[0]))) {
    return false;
  }
  // Process WM_INPUT notifications
  raw_input_data_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate([this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
    case WM_INPUT: {
      UINT dw_size = sizeof(RAWINPUT);
      static BYTE lpb[sizeof(RAWINPUT)];
      GetRawInputData((HRAWINPUT)lparam, RID_INPUT, lpb, &dw_size, sizeof(RAWINPUTHEADER));
      RAWINPUT* raw = (RAWINPUT*)lpb;
      if (raw->header.dwType == RIM_TYPEMOUSE) {
        last_x_delta_ = raw->data.mouse.lLastX;
        last_y_delta_ = raw->data.mouse.lLastY;
      }
      return std::nullopt;
    }
    default:
      return std::nullopt;
    }
  });
  return true;
}

void PointerLockPlugin::UnsubscribeFromRawInputData() {
  if (!SubscribedToRawInputData()) {
    return;
  }
  registrar_->UnregisterTopLevelWindowProcDelegate(raw_input_data_proc_id_.value());
  raw_input_data_proc_id_.reset();
}

bool PointerLockPlugin::SubscribedToRawInputData() {
  return raw_input_data_proc_id_.has_value();
}

PointerLockSessionStreamHandler::PointerLockSessionStreamHandler(flutter::PluginRegistrarWindows* registrar) {
  registrar_ = registrar;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> PointerLockSessionStreamHandler::OnListenInternal(
  const flutter::EncodableValue* arguments, 
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events
) {
  session_ = std::make_unique<PointerLockSession>(registrar_, std::move(events));
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> PointerLockSessionStreamHandler::OnCancelInternal(const flutter::EncodableValue* arguments) {
  session_.reset();
  return nullptr;
}

PointerLockSession::PointerLockSession(
  flutter::PluginRegistrarWindows* registrar,
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink
) : registrar_(registrar), sink_(std::move(sink)), locked_cursor_pos_() {
  // Remember the current cursor position so that we can restore it on each mouse move
  GetCursorPos(&locked_cursor_pos_);
  // Listen to mouse moves and mouse button releases
  SetCapture(GetParent(registrar_->GetView()->GetNativeWindow()));
  proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(std::move(
    [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
      switch (message) {
      case WM_MOUSEMOVE: {
        // Restore initial cursor position (this is what actually locks the pointer).
        // This needs to happen synchronously, right here in the event handler. Otherwise
        // things get very flaky. If this wouldn't be the case, we could do everything on 
        // Flutter side and wouldn't even need an EventChannel approach.
        SetCursorPos(locked_cursor_pos_.x, locked_cursor_pos_.y);
        // Calculate mouse move delta
        int x = GET_X_LPARAM(lparam);
        int y = GET_Y_LPARAM(lparam);
        int xDelta = 0;
        int yDelta = 0;
        if (last_cursor_pos_.has_value()) {
          auto p = last_cursor_pos_.value();
          xDelta = x - std::get<0>(p);
          yDelta = y - std::get<1>(p);
        }
        last_cursor_pos_ = std::make_tuple(x, y);
        // Send mouse move delta to Flutter
        std::vector<double> vec{
          static_cast<double>(xDelta),
          static_cast<double>(yDelta)
        };
        sink_->Success(flutter::EncodableValue(std::move(vec)));
        return std::nullopt;
      }
      case WM_LBUTTONUP:
      case WM_RBUTTONUP: {
        // A popular use case is to start the pointer-lock session when the user presses a mouse
        // button down and end it on release of a button. Unfortunately, SetCapture prevents Flutter
        // from receiving mouse events, so we can't listen to the button release on Flutter side.
        // That's why we do it here. Sending an end-of-stream event to Flutter will trigger OnCancelInternal()
        // and that will release the capture.  
        // TODO Make this more flexible. I can imagine there are cases where the pointer-lock session
        //  is not controlled by button press/release.
        sink_->EndOfStream();
        return std::nullopt;
      }
      default:
        return std::nullopt;
      }
    }
  ));
}

PointerLockSession::~PointerLockSession() {
  registrar_->UnregisterTopLevelWindowProcDelegate(proc_id_);
  ReleaseCapture();
}

}  // namespace pointer_lock
