#include "../../windows/runner/steam_session.h"
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace fs = std::filesystem;
void Require(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
void Pump(DWORD milliseconds) {
  const auto until = GetTickCount64() + milliseconds;
  do {
    MSG message;
    while (PeekMessage(&message, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&message); DispatchMessage(&message); }
    Sleep(10);
  } while (GetTickCount64() < until);
}
LRESULT CALLBACK Fixture(HWND hwnd, UINT message, WPARAM wp, LPARAM lp) {
  if (message == WM_CLOSE) { DestroyWindow(hwnd); return 0; }
  if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
  return DefWindowProc(hwnd, message, wp, lp);
}
HWND Window(const fs::path& executable) {
  auto normalized = executable;
  normalized.make_preferred();
  return FindWindowW(L"RyhzeSteamWindowFixture", normalized.c_str());
}
void Spawn(const fs::path& executable) {
  STARTUPINFOW startup{}; startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  Require(CreateProcessW(executable.c_str(), nullptr, nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process) != FALSE, "fixture launch");
  CloseHandle(process.hThread); CloseHandle(process.hProcess);
}
int wmain() {
  wchar_t path[32768]; GetModuleFileNameW(nullptr, path, 32768);
  const fs::path self(path);
  if (self.filename() != L"steam_session_test.exe") {
    WNDCLASSW type{}; type.lpfnWndProc = Fixture; type.hInstance = GetModuleHandle(nullptr); type.lpszClassName = L"RyhzeSteamWindowFixture";
    RegisterClassW(&type);
    // Real native child windows, kept offscreen and never activated.
    const HWND hwnd = CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, type.lpszClassName, path, WS_POPUP, -20000, -20000, 320, 200, nullptr, nullptr, type.hInstance, nullptr);
    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
    MSG message; while (GetMessage(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessage(&message); }
    return 0;
  }
  const auto temp = fs::temp_directory_path() / (L"ryhze-steam-check-" + std::to_wstring(GetCurrentProcessId()));
  const std::vector<fs::path> files = {temp / L"Steam/steam.exe", temp / L"Steam/bin/steamwebhelper.exe", temp / L"Games/Game.exe", temp / L"Other/steam.exe"};
  int status = 0;
  try {
    for (const auto& file : files) { fs::create_directories(file.parent_path()); fs::copy_file(self, file); }
    SteamSession session(nullptr, files[0].wstring());
    std::string error;
    Require(!session.Launch("123 & exit", error), "reject command injection");
    Require(!session.Launch("4294967296", error), "reject oversized app ID");
    Require(session.Launch("123", error), "launch valid Steam game");
    Require(!session.Launch("123", error), "reject duplicate launch");
    Spawn(files[1]); Spawn(files[2]); Spawn(files[3]);
    Pump(800);
    for (const auto& file : files) Require(Window(file) != nullptr, "fixture window exists");
    Require(!IsWindowVisible(Window(files[0])), "Steam launch window hidden");
    Require(!IsWindowVisible(Window(files[1])), "Steam webhelper window hidden");
    Require(IsWindowVisible(Window(files[2])), "game window preserved");
    Require(IsWindowVisible(Window(files[3])), "unrelated same-name app preserved");
    session.Update("123", false, true);
    ShowWindow(Window(files[0]), SW_SHOWNOACTIVATE); Pump(200);
    Require(!IsWindowVisible(Window(files[0])), "no finish before running detection");
    DWORD pid = 0; GetWindowThreadProcessId(Window(files[0]), &pid);
    HANDLE steam = OpenProcess(SYNCHRONIZE, FALSE, pid);
    Require(steam && WaitForSingleObject(steam, 0) == WAIT_TIMEOUT, "Steam process remains alive");
    if (steam) CloseHandle(steam);
    session.Update("123", true, false);
    session.Update("123", false, true);
    Pump(2700);
    ShowWindow(Window(files[0]), SW_SHOWNOACTIVATE); Pump(200);
    Require(IsWindowVisible(Window(files[0])), "monitor releases after confirmed finish");
    Require(session.Launch("456", error), "new independent session");
    Pump(400); session.Cancel("456");
    // Both fixture processes use the same executable; every owned window may reopen.
    ShowWindow(Window(files[0]), SW_SHOWNOACTIVATE); Pump(200);
    Require(IsWindowVisible(Window(files[0])), "cancellation releases Steam UI");
    std::cout << "Steam ownership, delayed windows, duplicate launch, completion and cancellation passed.\n";
  } catch (const std::exception& error) { std::cerr << error.what() << '\n'; status = 1; }
  for (const auto& file : files) {
    while (const auto window = Window(file)) { PostMessage(window, WM_CLOSE, 0, 0); Pump(100); }
  }
  std::error_code error;
  if (fs::weakly_canonical(temp).parent_path() == fs::weakly_canonical(fs::temp_directory_path()) &&
      temp.filename() == L"ryhze-steam-check-" + std::to_wstring(GetCurrentProcessId())) {
    fs::remove_all(temp, error);
  } else { std::cerr << "Unexpected fixture cleanup path\n"; status = 1; }
  return status;
}
