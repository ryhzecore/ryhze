#include <windows.h>
#include <tlhelp32.h>
#include <commdlg.h>
#include <string>
#include <vector>
#include "game_library.h"
#include "race_installation.h"

namespace {
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
using L = flutter::EncodableList;
std::string Utf8(const std::wstring& s) {
  if (s.empty()) return {};
  int n = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
  std::string out(n, 0);
  WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), n, nullptr, nullptr);
  return out;
}
std::string RegString(HKEY hive, const wchar_t* key, const wchar_t* value) {
  wchar_t buffer[32768]; DWORD size = sizeof(buffer);
  if (RegGetValueW(hive, key, value, RRF_RT_REG_SZ, nullptr, buffer, &size) != ERROR_SUCCESS) return {};
  return Utf8(buffer);
}
std::string Image(HANDLE process) {
  wchar_t path[32768]; DWORD size = 32768;
  return QueryFullProcessImageNameW(process, 0, path, &size) ? Utf8(std::wstring(path, size)) : "";
}
std::string Birth(HANDLE process) {
  FILETIME created, exited, kernel, user;
  if (!GetProcessTimes(process, &created, &exited, &kernel, &user)) return "";
  ULARGE_INTEGER time; time.LowPart = created.dwLowDateTime; time.HighPart = created.dwHighDateTime;
  return std::to_string(time.QuadPart);
}
struct WindowSearch { DWORD pid; HWND window = nullptr; };
BOOL CALLBACK FindWindow(HWND window, LPARAM data) {
  auto* search = reinterpret_cast<WindowSearch*>(data);
  DWORD pid = 0; GetWindowThreadProcessId(window, &pid);
  if (pid == search->pid && IsWindowVisible(window) && GetWindow(window, GW_OWNER) == nullptr) {
    search->window = window; return FALSE;
  }
  return TRUE;
}
HWND GameWindow(DWORD pid) {
  WindowSearch search{pid}; EnumWindows(FindWindow, reinterpret_cast<LPARAM>(&search)); return search.window;
}
std::string Field(const M& args, const char* key) {
  auto it = args.find(V(key));
  if (it == args.end()) return "";
  auto text = std::get_if<std::string>(&it->second); return text ? *text : "";
}
}

std::unique_ptr<flutter::MethodChannel<V>> CreateGameLibrary(flutter::BinaryMessenger* messenger, HWND owner) {
  auto channel = std::make_unique<flutter::MethodChannel<V>>(messenger, "ryhze/game_library", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([owner](const auto& call, auto result) {
    if (call.method_name() == "raceInstallation") {
      const auto* args = call.arguments() ? std::get_if<M>(call.arguments()) : nullptr;
      result->Success(FindRaceInstallation(args ? Field(*args, "path") : "")); return;
    }
    if (call.method_name() == "roots") {
      L steam;
      for (const auto& value : {
        RegString(HKEY_CURRENT_USER, L"Software\\Valve\\Steam", L"SteamPath"),
        RegString(HKEY_LOCAL_MACHINE, L"SOFTWARE\\WOW6432Node\\Valve\\Steam", L"InstallPath"),
        RegString(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Valve\\Steam", L"InstallPath")}) {
        if (!value.empty()) steam.emplace_back(value);
      }
      result->Success(V(M{{V("steam"), V(steam)}})); return;
    }
    if (call.method_name() == "pickExecutable") {
      wchar_t path[32768] = {};
      OPENFILENAMEW dialog{}; dialog.lStructSize = sizeof(dialog); dialog.hwndOwner = owner;
      dialog.lpstrFile = path; dialog.nMaxFile = 32768;
      dialog.lpstrFilter = L"Game executable (*.exe)\0*.exe\0\0";
      dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
      result->Success(V(GetOpenFileNameW(&dialog) ? Utf8(path) : "")); return;
    }
    if (call.method_name() == "processes") {
      L processes;
      HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
      if (snapshot == INVALID_HANDLE_VALUE) { result->Error("snapshot", "Windows could not read game activity."); return; }
      PROCESSENTRY32W entry{}; entry.dwSize = sizeof(entry);
      if (Process32FirstW(snapshot, &entry)) do {
        if (entry.th32ProcessID == GetCurrentProcessId()) continue;
        HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, entry.th32ProcessID);
        if (!process) continue;
        auto path = Image(process); auto birth = Birth(process); CloseHandle(process);
        if (!path.empty() && !birth.empty()) processes.emplace_back(M{
          {V("pid"), V(static_cast<int64_t>(entry.th32ProcessID))}, {V("path"), V(path)},
          {V("birth"), V(birth)}, {V("window"), V(GameWindow(entry.th32ProcessID) != nullptr)}});
      } while (Process32NextW(snapshot, &entry));
      CloseHandle(snapshot); result->Success(V(processes)); return;
    }
    if (call.method_name() == "resume" || call.method_name() == "stop" || call.method_name() == "forceStop") {
      const auto* args = std::get_if<M>(call.arguments());
      if (!args) { result->Error("arguments", "Invalid game process."); return; }
      auto pidValue = args->find(V("pid")); int64_t pid = 0;
      if (pidValue != args->end()) {
        if (auto n = std::get_if<int32_t>(&pidValue->second)) pid = *n;
        if (auto n = std::get_if<int64_t>(&pidValue->second)) pid = *n;
      }
      if (pid <= 0 || pid == GetCurrentProcessId()) { result->Error("process", "Game has already closed."); return; }
      const bool force = call.method_name() == "forceStop";
      HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | (force ? PROCESS_TERMINATE : 0), FALSE, static_cast<DWORD>(pid));
      // Validate creation time and full image again: a recycled PID must never affect another application.
      if (!process || Birth(process) != Field(*args, "birth") || Image(process) != Field(*args, "path")) {
        if (process) CloseHandle(process);
        result->Error("process", "Game has closed or Windows denied access. Refresh and try again."); return;
      }
      HWND window = GameWindow(static_cast<DWORD>(pid)); bool ok = false;
      if (force) ok = TerminateProcess(process, 0) != FALSE;
      else if (window && call.method_name() == "stop") ok = PostMessageW(window, WM_CLOSE, 0, 0) != FALSE;
      else if (window) { if (IsIconic(window)) ShowWindowAsync(window, SW_RESTORE); ok = SetForegroundWindow(window) != FALSE; }
      CloseHandle(process);
      if (ok) result->Success();
      else result->Error("window", "Windows could not control the game window. Switch with Alt+Tab, or use the game's own exit menu.");
      return;
    }
    result->NotImplemented();
  });
  return channel;
}
