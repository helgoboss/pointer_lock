#include "pointer_lock_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <hidusage.h>

namespace pointer_lock {

// static
void PointerLockPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "pointer_lock",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PointerLockPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

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
    POINT cursorPos;
    if (!GetCursorPos(&cursorPos)) {
      result->Error("UNAVAILABLE", "Couldn't get current cursor position");
      return;
    }
    RECT rect{ cursorPos.x, cursorPos.y, cursorPos.x, cursorPos.y };
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
      static_cast<double>(lastXDelta_),
      static_cast<double>(lastYDelta_)
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
  rawInputDataProcId_ = registrar_->RegisterTopLevelWindowProcDelegate([this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
    case WM_INPUT: {
      UINT dwSize = sizeof(RAWINPUT);
      static BYTE lpb[sizeof(RAWINPUT)];
      GetRawInputData((HRAWINPUT)lparam, RID_INPUT, lpb, &dwSize, sizeof(RAWINPUTHEADER));
      RAWINPUT* raw = (RAWINPUT*)lpb;
      if (raw->header.dwType == RIM_TYPEMOUSE) {
        lastXDelta_ = raw->data.mouse.lLastX;
        lastYDelta_ = raw->data.mouse.lLastY;
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
  registrar_->UnregisterTopLevelWindowProcDelegate(rawInputDataProcId_.value());
  rawInputDataProcId_.reset();
}

bool PointerLockPlugin::SubscribedToRawInputData() {
  return rawInputDataProcId_.has_value();
}

}  // namespace pointer_lock
