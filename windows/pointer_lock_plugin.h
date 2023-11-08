#ifndef FLUTTER_PLUGIN_POINTER_LOCK_PLUGIN_H_
#define FLUTTER_PLUGIN_POINTER_LOCK_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
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

struct PointerLockSession {
public:
  PointerLockSession(flutter::PluginRegistrarWindows* registrar, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  ~PointerLockSession();
private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  POINT lockedCursorPos_;
  std::optional<std::tuple<int, int>> lastCursorPos_;
  int procId_;
};

class PointerLockSessionStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
public:
  PointerLockSessionStreamHandler(flutter::PluginRegistrarWindows* registrar);

protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(const flutter::EncodableValue* arguments, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(const flutter::EncodableValue* arguments) override;

private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<PointerLockSession> session_;
};

}  // namespace pointer_lock

#endif  // FLUTTER_PLUGIN_POINTER_LOCK_PLUGIN_H_
