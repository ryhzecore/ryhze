#ifndef RYHZE_GAME_LIBRARY_H_
#define RYHZE_GAME_LIBRARY_H_
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateGameLibrary(flutter::BinaryMessenger* messenger, HWND window);
#endif
