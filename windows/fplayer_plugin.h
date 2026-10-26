#ifndef FLUTTER_PLUGIN_FPLAYER_PLUGIN_H_
#define FLUTTER_PLUGIN_FPLAYER_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

#include "fplayer.h"

namespace fplayer {

class FplayerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit FplayerPlugin(flutter::PluginRegistrarWindows* registrar);
  ~FplayerPlugin() override;

  FplayerPlugin(const FplayerPlugin&) = delete;
  FplayerPlugin& operator=(const FplayerPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandlePlatformMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar() const { return registrar_; }

  void RequestDrain();

 private:
  static constexpr UINT kDrainMessage = WM_APP + 0x51;
  static LRESULT CALLBACK DrainWndProc(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

  void DrainPlayers();
  void RegisterEventChannel();

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      platform_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      plugin_event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
      plugin_event_sink_;
  std::map<int, std::unique_ptr<FPlayer>> players_;
  int next_player_id_ = 0;
  HWND message_hwnd_ = nullptr;
};

}  // namespace fplayer

#endif
