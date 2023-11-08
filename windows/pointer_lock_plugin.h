#ifndef FLUTTER_PLUGIN_POINTER_LOCK_PLUGIN_H_
#define FLUTTER_PLUGIN_POINTER_LOCK_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace pointer_lock {

class PointerLockPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PointerLockPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~PointerLockPlugin();

  // Disallow copy and assign.
  PointerLockPlugin(const PointerLockPlugin&) = delete;
  PointerLockPlugin& operator=(const PointerLockPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
   flutter::PluginRegistrarWindows* registrar_;
   std::optional<int> rawInputDataProcId_;
   LONG lastXDelta_ = 0;
   LONG lastYDelta_ = 0;

   bool SubscribeToRawInputData();
   void UnsubscribeFromRawInputData();
   bool SubscribedToRawInputData();
};

}  // namespace pointer_lock

#endif  // FLUTTER_PLUGIN_POINTER_LOCK_PLUGIN_H_
