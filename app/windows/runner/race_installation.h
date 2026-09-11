#pragma once
#include <windows.h>
#include <filesystem>
#include <string>
#include <vector>
#include <flutter/encodable_value.h>

// Read Windows directly: launcher detection must not depend on a shell or PATH.
inline flutter::EncodableValue FindRaceInstallation(const std::string& selected = {}) {
  namespace fs = std::filesystem;
  using V = flutter::EncodableValue;
  std::vector<fs::path> candidates;
  if (!selected.empty()) candidates.push_back(fs::u8path(selected));
  if (selected.empty()) {
  for (auto hive : {HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE}) {
    for (const auto* key : {L"Software\\RACE", L"Software\\WOW6432Node\\RACE",
                           L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\RACE"}) {
      for (const auto* field : {L"InstallDir", L"InstallLocation"}) {
        wchar_t path[32768]{}; DWORD bytes = sizeof(path);
        if (RegGetValueW(hive, key, field, RRF_RT_REG_SZ, nullptr, path, &bytes) == ERROR_SUCCESS && path[0])
          candidates.emplace_back(path);
      }
    }
  }
  for (const auto* variable : {L"LOCALAPPDATA", L"ProgramFiles", L"ProgramFiles(x86)"}) {
    wchar_t root[32768]{};
    const auto length = GetEnvironmentVariableW(variable, root, 32768);
    if (length && length < 32768) {
      candidates.push_back(fs::path(root) / L"RACE");
      candidates.push_back(fs::path(root) / L"Programs" / L"RACE");
    }
  }
  }
  for (auto path : candidates) {
    std::error_code error;
    if (path.filename() == L"race_editor.exe") path = path.parent_path();
    path = fs::absolute(path, error);
    if (error) continue;
    auto executable = path / L"race_editor.exe";
    if (!fs::is_regular_file(executable, error) ||
        !fs::is_regular_file(path / L"data" / L"app.so", error) ||
        !fs::is_regular_file(path / L"race_editor_bridge.dll", error)) continue;
    DWORD unused = 0;
    const DWORD size = GetFileVersionInfoSizeW(executable.c_str(), &unused);
    if (!size || size > 1024 * 1024) continue;
    std::vector<BYTE> buffer(size);
    if (!GetFileVersionInfoW(executable.c_str(), 0, size, buffer.data())) continue;
    VS_FIXEDFILEINFO* info = nullptr; UINT count = 0;
    if (!VerQueryValueW(buffer.data(), L"\\", reinterpret_cast<void**>(&info), &count) ||
        count < sizeof(VS_FIXEDFILEINFO) || info->dwSignature != 0xfeef04bd) continue;
    const auto version = std::to_string(HIWORD(info->dwProductVersionMS)) + "." +
      std::to_string(LOWORD(info->dwProductVersionMS)) + "." +
      std::to_string(HIWORD(info->dwProductVersionLS));
    return V(flutter::EncodableMap{{V("path"), V(path.u8string())},
      {V("executable"), V(executable.u8string())}, {V("version"), V(version)},
      {V("build"), V(static_cast<int32_t>(LOWORD(info->dwProductVersionLS)))}});
  }
  return V();
}
