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


	int print_log(const char* format, ...)
	{
		static char s_printf_buf[1024];
		va_list args;
		va_start(args, format);
		_vsnprintf_s(s_printf_buf, sizeof(s_printf_buf), format, args);
		va_end(args);
		OutputDebugStringA(s_printf_buf);
		return 0;
	}

	// static
	void PointerLockPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
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
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
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
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		if (method_call.method_name().compare("pointerPositionOnScreen") == 0) {
			POINT cursor_pos;
			if (!GetCursorPos(&cursor_pos)) {
				result->Error("UNAVAILABLE", "Couldn't get current cursor position");
				return;
			}
			std::vector<double> vec{
				static_cast<double>(cursor_pos.x),
				static_cast<double>(cursor_pos.y)
			};
			result->Success(flutter::EncodableValue(std::move(vec)));
		}
		else if (method_call.method_name().compare("lockPointer") == 0) {
			POINT cursor_pos;
			if (!GetCursorPos(&cursor_pos)) {
				result->Error("UNAVAILABLE", "Couldn't get current cursor position");
				return;
			}
			RECT rect{ cursor_pos.x, cursor_pos.y, cursor_pos.x, cursor_pos.y };
			ClipCursor(&rect);
			result->Success();
		}
		else if (method_call.method_name().compare("unlockPointer") == 0) {
			ClipCursor(NULL);
			result->Success();
		}
		else if (method_call.method_name().compare("hidePointer") == 0) {
			if (pointer_visible_) {
				pointer_visible_ = false;
				ShowCursor(0);
			}
			result->Success();
		}
		else if (method_call.method_name().compare("showPointer") == 0) {
			if (!pointer_visible_) {
				pointer_visible_ = true;
				ShowCursor(1);
			}
			result->Success();
		}
		else if (method_call.method_name().compare("subscribeToRawInputData") == 0) {
			if (!SubscribeToRawInputData()) {
				result->Error("UNAVAILABLE", "Couldn't subscribe to raw input data");
				return;
			}
			result->Success();
		}
		else if (method_call.method_name().compare("lastPointerDelta") == 0) {
			if (!SubscribedToRawInputData()) {
				result->Error("ACTION_REQUIRED", "On Windows, you must call 'subscribeToRawInputData()' first.");
				return;
			}
			std::vector<double> vec{
			  static_cast<double>(last_x_delta_),
			  static_cast<double>(last_y_delta_)
			};
			result->Success(flutter::EncodableValue(std::move(vec)));
		}
		else {
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
		// Process WM_INPUT notifications (extract mouse deltas)
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
		// This clears the session object, causing its destrutor to run, which in turn releases the capture.
		session_.reset();
		return nullptr;
	}

	UINT find_button_down_msg(UINT button_up_msg) {
		switch (button_up_msg) {
		case WM_LBUTTONUP: return WM_LBUTTONDOWN;
		case WM_RBUTTONUP: return WM_RBUTTONDOWN;
		case WM_MBUTTONUP: return WM_MBUTTONDOWN;
		case WM_XBUTTONUP: return WM_XBUTTONDOWN;
		default: return 0;
		}
	}

	PointerLockSession::PointerLockSession(
		flutter::PluginRegistrarWindows* registrar,
		std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink
	) : registrar_(registrar), sink_(std::move(sink)), locked_pointer_screen_pos_() {
		// Remember the current cursor position so that we can restore it on each mouse move
		GetCursorPos(&locked_pointer_screen_pos_);
		// Listen to mouse moves and mouse button releases. Below delegate will receive the mouse messages only
		// if we capture the **parent** of the native window. Only the delegate will receive the mouse messages,
		// not the rest of the Flutter app.
		HWND native_window = registrar_->GetView()->GetNativeWindow();
		HWND parent_window = GetParent(native_window);
		SetCapture(parent_window);
		bool moved = false;
		bool sent_pseudo_button_down = false;
		proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(std::move(
			[this, native_window, parent_window, moved, sent_pseudo_button_down](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) mutable -> std::optional<LRESULT> {
				switch (message) {
				case WM_MOUSEMOVE: {
					moved = true;
					// Restore initial cursor position (this is what actually locks the pointer).
					// This needs to happen synchronously, right here in the event handler. Otherwise
					// things get very flaky. If this wouldn't be the case, we could do everything on 
					// Flutter side and wouldn't even need an EventChannel approach.
					if (!SetCursorPos(locked_pointer_screen_pos_.x, locked_pointer_screen_pos_.y)) {
						return std::nullopt;
					}
					// Calculate mouse move delta
					int x = GET_X_LPARAM(lparam);
					int y = GET_Y_LPARAM(lparam);
					POINT locked_pointer_window_pos = locked_pointer_screen_pos_;
					ScreenToClient(hwnd, &locked_pointer_window_pos);
					int x_delta = x - locked_pointer_window_pos.x;
					int y_delta = y - locked_pointer_window_pos.y;
					if (x_delta == 0 && y_delta == 0) {
						return 0;
					}
					// Send mouse move delta to Flutter
					std::vector<double> vec{
					  static_cast<double>(x_delta),
					  static_cast<double>(y_delta)
					};
					sink_->Success(flutter::EncodableValue(std::move(vec)));
					// We handled this message sufficiently. Any other redirection of mouse-move messages would just complicate things.
					return 0;
				}
				case WM_LBUTTONUP:
				case WM_RBUTTONUP:
				case WM_MBUTTONUP:
				case WM_XBUTTONUP:
				case WM_LBUTTONDOWN:
				case WM_RBUTTONDOWN:
				case WM_MBUTTONDOWN:
				case WM_XBUTTONDOWN:
				case WM_LBUTTONDBLCLK:
				case WM_RBUTTONDBLCLK:
				case WM_MBUTTONDBLCLK:
				case WM_XBUTTONDBLCLK:
					// We want to forward button clicks to the rest of the Flutter app. The Dart code might be interested in them.
					// There's a corner case that is relevant for the "release pointer lock after dragging" use case. As soon as the pointer
					// moves while SetCapture is set, Flutter emits a pointer-cancel and pointer-remove event (probably indicating to Dart that the
					// pointer is not connected to the original window anymore). As a consequence, the first button-up event after the move will just result
					// in a pointer-add event to be emitted. In order to submit it as a complete event, we synthesize a corresponding button-down event
					// and send it directly before forwarding the button-up event. Yes, this results in a complete click at Dart side, but it works
					// for most cases and I don't know any better alternative.
					if (moved && !sent_pseudo_button_down) {
						UINT button_down_msg = find_button_down_msg(message);
						if (button_down_msg > 0) {
							sent_pseudo_button_down = true;
							SendMessage(native_window, button_down_msg, wparam, lparam);
						}
					}
					// Forward the actual message
					SendMessage(native_window, message, wparam, lparam);
					// There are situations when Flutter calls SetCapture itself, for example, when pressing the left button. We need to take SetCapture back!
					SetCapture(parent_window);
					return 0;
				default:
					// Not handled
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
