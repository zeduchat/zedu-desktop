#include <app_links/app_links_plugin_c_api.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kWindowTitle[] = L"Zedu";

// Debug builds skip this so `flutter run` still works while Zedu is installed
// and running.
#ifndef _DEBUG
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kInstanceMutexName[] =
    L"Local\\ZeduDesktopSingleInstance";
constexpr DWORD kInstanceWaitStepMs = 100;
constexpr int kInstanceWaitSteps = 300;

// Forwards this launch's zedu:// link, if any, and brings the window to front.
void ActivateRunningInstance(HWND window) {
  SendAppLink(window);
  ::ShowWindow(window, ::IsIconic(window) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(window);
}

// Returns whether this process should run the app. The process keeps the
// mutex until it exits, which is what marks it as the running copy.
//
// A copy that is closing holds the mutex for a few seconds after its window
// has gone, so a missing window isn't treated as "already running": this keeps
// checking, and takes over once that copy exits. Otherwise reopening Zedu right
// after closing it would do nothing.
bool ClaimSingleInstance() {
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kInstanceMutexName);
  if (mutex == nullptr || ::GetLastError() != ERROR_ALREADY_EXISTS) {
    return true;
  }

  for (int step = 0; step < kInstanceWaitSteps; step++) {
    if (HWND window = ::FindWindowW(kWindowClassName, kWindowTitle)) {
      ActivateRunningInstance(window);
      return false;
    }
    const DWORD wait = ::WaitForSingleObject(mutex, kInstanceWaitStepMs);
    if (wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED) {
      return true;
    }
  }
  return false;
}
#endif

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#ifndef _DEBUG
  if (!ClaimSingleInstance()) {
    return EXIT_SUCCESS;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
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
  return EXIT_SUCCESS;
}
