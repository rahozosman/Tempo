#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// One Tempo per sign-in session. A second launch — from the Start menu, a
// shortcut, or "launch at startup" arriving after a manual open — must not
// become a second tracker with its own tray icon: it wakes the copy already
// running and leaves.
constexpr const wchar_t kInstanceMutexName[] = L"Local\\Tempo.SingleInstance";
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"Tempo";

// Passed by the system when Tempo is opened at sign-in. It must be read here
// as well as in Dart: the runner is what puts the window on screen, so it is
// the runner that has to know not to.
constexpr const char kHiddenLaunchFlag[] = "--hidden";

// Finds the running Tempo's window, skipping any window that belongs to this
// process. The running copy may be hidden in the tray, so it is searched for
// rather than assumed visible.
HWND FindRunningTempoWindow() {
  const DWORD self = ::GetCurrentProcessId();
  HWND candidate = nullptr;
  while ((candidate = ::FindWindowExW(nullptr, candidate, kWindowClassName,
                                      kWindowTitle)) != nullptr) {
    DWORD owner = 0;
    ::GetWindowThreadProcessId(candidate, &owner);
    if (owner != self) {
      return candidate;
    }
  }
  return nullptr;
}

// Brings the running copy to the front, restoring it from the tray or from a
// minimised state first. The process that was just launched is the foreground
// process, which is what allows it to hand the foreground to another window.
void ActivateRunningTempo(HWND window) {
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }
  ::ShowWindow(window, SW_SHOW);
  ::SetForegroundWindow(window);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool start_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                kHiddenLaunchFlag) != command_line_arguments.end();

  // Claimed for the life of the process; released by the system when it ends,
  // however it ends, so a crash never locks the app out.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, TRUE, kInstanceMutexName);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // A person opening Tempo again is asking to see it. The system opening it
    // at sign-in, on top of a copy already measuring, is asking for nothing —
    // that launch leaves without disturbing the window.
    if (!start_hidden) {
      HWND running = FindRunningTempoWindow();
      if (running != nullptr) {
        ActivateRunningTempo(running);
      }
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex != nullptr) {
    ::ReleaseMutex(instance_mutex);
    ::CloseHandle(instance_mutex);
  }
  return EXIT_SUCCESS;
}
