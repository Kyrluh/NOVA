#include "flutter_window.h"

#include <optional>
#include <windowsx.h>
#include <shellapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  media_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "nova/media_keys",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "nova/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getUpdateInfo") {
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("platform"), flutter::EncodableValue("windows")},
              {flutter::EncodableValue("version"), flutter::EncodableValue(FLUTTER_VERSION)},
              {flutter::EncodableValue("build"), flutter::EncodableValue(FLUTTER_VERSION_BUILD)},
          }));
        } else if (call.method_name() == "openUpdateUrl") {
          const auto* url = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
          const std::string prefix = "https://github.com/Kyrluh/NOVA/releases/download/";
          if (!url || url->rfind(prefix, 0) != 0 || url->size() < 4 ||
              url->substr(url->size() - 4) != ".zip" || url->find_first_of("?#\r\n") != std::string::npos) {
            result->Error("invalid_url", "Invalid NOVA release URL.");
          } else {
            const std::wstring address(url->begin(), url->end());
            if (reinterpret_cast<INT_PTR>(::ShellExecuteW(GetHandle(), L"open", address.c_str(), nullptr, nullptr, SW_SHOWNORMAL)) > 32) {
              result->Success();
            } else {
              result->Error("browser_unavailable", "Unable to open the download.");
            }
          }
        } else if (call.method_name() == "isFullscreen") {
          result->Success(flutter::EncodableValue(fullscreen_));
        } else if (call.method_name() == "setFullscreen") {
          const auto* enabled = call.arguments()
              ? std::get_if<bool>(call.arguments()) : nullptr;
          if (!enabled) {
            result->Error("invalid_argument", "Expected a fullscreen flag.");
          } else if (SetFullscreen(*enabled)) {
            result->Success();
          } else {
            result->Error("fullscreen_failed", "Unable to change the window mode.");
          }
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  media_channel_.reset();
  window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

bool FlutterWindow::SetFullscreen(bool enabled) {
  if (enabled == fullscreen_) return true;
  HWND window = GetHandle();
  if (!window) return false;
  if (enabled) {
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    saved_placement_.length = sizeof(saved_placement_);
    if (!::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor) ||
        !::GetWindowPlacement(window, &saved_placement_)) {
      return false;
    }
    saved_style_ = ::GetWindowLongPtr(window, GWL_STYLE);
    saved_ex_style_ = ::GetWindowLongPtr(window, GWL_EXSTYLE);
    // Clear maximization before changing the frame. The saved placement keeps
    // its original show state, so restoring a maximized window remains exact.
    if (::IsZoomed(window)) ::ShowWindow(window, SW_RESTORE);
    const LONG_PTR borderless = saved_style_ &
        ~(static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW) | WS_MAXIMIZE | WS_MINIMIZE);
    ::SetWindowLongPtr(window, GWL_STYLE, borderless);
    ::SetWindowLongPtr(window, GWL_EXSTYLE,
        saved_ex_style_ & ~(WS_EX_DLGMODALFRAME | WS_EX_CLIENTEDGE |
                            WS_EX_STATICEDGE | WS_EX_WINDOWEDGE));
    if (!::SetWindowPos(window, HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
          monitor.rcMonitor.right - monitor.rcMonitor.left,
          monitor.rcMonitor.bottom - monitor.rcMonitor.top,
          SWP_FRAMECHANGED | SWP_NOOWNERZORDER)) {
      ::SetWindowLongPtr(window, GWL_STYLE, saved_style_);
      ::SetWindowLongPtr(window, GWL_EXSTYLE, saved_ex_style_);
      ::SetWindowPlacement(window, &saved_placement_);
      return false;
    }
    fullscreen_ = true;
  } else {
    ::SetWindowLongPtr(window, GWL_STYLE,
        saved_style_ & ~(static_cast<LONG_PTR>(WS_MAXIMIZE) | WS_MINIMIZE));
    ::SetWindowLongPtr(window, GWL_EXSTYLE, saved_ex_style_);
    ::SetWindowPlacement(window, &saved_placement_);
    ::SetWindowPos(window, nullptr, 0, 0, 0, 0,
        SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
        SWP_NOACTIVATE | SWP_NOOWNERZORDER);
    fullscreen_ = false;
  }
  return true;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Standard multimedia buttons (including Corsair keyboards) may arrive as
  // WM_APPCOMMAND instead of Flutter keyboard events. Consume the command here
  // so DefWindowProc cannot dispatch it a second time.
  if (message == WM_APPCOMMAND && media_channel_) {
    const int command = GET_APPCOMMAND_LPARAM(lparam);
    const char* action = nullptr;
    if (command == APPCOMMAND_MEDIA_PLAY_PAUSE) action = "playPause";
    if (command == APPCOMMAND_MEDIA_PLAY) action = "play";
    if (command == APPCOMMAND_MEDIA_PAUSE) action = "pause";
    if (action) {
      media_channel_->InvokeMethod("mediaCommand",
          std::make_unique<flutter::EncodableValue>(std::string(action)));
      return TRUE;
    }
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
