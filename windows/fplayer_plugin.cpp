#include "fplayer_plugin.h"

#include <flutter/event_stream_handler_functions.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>
#include <utility>

#include "fplayer_protocol.h"
#include "fplayercore.h"

namespace fplayer {
namespace {

constexpr wchar_t kDrainClass[] = L"FplayerDrainWindow";

const flutter::EncodableValue* FindValue(const flutter::EncodableMap& map,
                                         const char* key) {
  const auto it = map.find(flutter::EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

int64_t IntValue(const flutter::EncodableValue* value) {
  if (value == nullptr) return 0;
  if (std::holds_alternative<int32_t>(*value) ||
      std::holds_alternative<int64_t>(*value)) {
    return value->LongValue();
  }
  return 0;
}

}

void FplayerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<FplayerPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

FplayerPlugin::FplayerPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  ijkff_global_init();
  ijkff_log_level(IJK_LOG_INFO);

  channel_ = std::make_unique<flutter::MethodChannel<
      flutter::EncodableValue>>(
      registrar_->messenger(), fplayer_protocol::kPluginChannel,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  platform_channel_ = std::make_unique<flutter::MethodChannel<
      flutter::EncodableValue>>(
      registrar_->messenger(), fplayer_protocol::kPlatformChannel,
      &flutter::StandardMethodCodec::GetInstance());
  platform_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandlePlatformMethodCall(call, std::move(result));
      });

  RegisterEventChannel();

  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = &FplayerPlugin::DrainWndProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kDrainClass;
  RegisterClassExW(&window_class);

  message_hwnd_ = CreateWindowExW(0, kDrainClass, L"", 0, 0, 0, 0, 0,
                                  HWND_MESSAGE, nullptr, window_class.hInstance,
                                  this);
}

FplayerPlugin::~FplayerPlugin() {
  players_.clear();
  if (message_hwnd_ != nullptr) {
    DestroyWindow(message_hwnd_);
    message_hwnd_ = nullptr;
  }
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (platform_channel_ != nullptr) {
    platform_channel_->SetMethodCallHandler(nullptr);
  }
  if (plugin_event_channel_ != nullptr) {
    plugin_event_channel_->SetStreamHandler(nullptr);
  }
  plugin_event_sink_.reset();
}

void FplayerPlugin::RegisterEventChannel() {
  plugin_event_channel_ = std::make_unique<
      flutter::EventChannel<flutter::EncodableValue>>(
      registrar_->messenger(), fplayer_protocol::kPluginEventChannel,
      &flutter::StandardMethodCodec::GetInstance());
  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<
                 flutter::EventSink<flutter::EncodableValue>>&& events) {
        plugin_event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const flutter::EncodableValue* arguments) {
        plugin_event_sink_.reset();
        return nullptr;
      });
  plugin_event_channel_->SetStreamHandler(std::move(handler));
}

void FplayerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments =
      method_call.arguments() == nullptr
          ? nullptr
          : std::get_if<flutter::EncodableMap>(method_call.arguments());
  const std::string& method = method_call.method_name();

  if (method == fplayer_protocol::kMethodCreatePlayer) {
    const int id = next_player_id_++;
    auto player = std::make_unique<FPlayer>(this, id);
    players_[id] = std::move(player);
    result->Success(flutter::EncodableValue(static_cast<int64_t>(id)));
  } else if (method == fplayer_protocol::kMethodReleasePlayer) {
    if (arguments != nullptr) {
      const int id = static_cast<int>(IntValue(FindValue(*arguments, "pid")));
      players_.erase(id);
    }
    result->Success();
  } else if (method == fplayer_protocol::kMethodGetPlatformVersion) {
    result->Success(flutter::EncodableValue(std::string("Windows")));
  } else if (method == fplayer_protocol::kMethodGetBatteryInfo) {
    SYSTEM_POWER_STATUS status = {};
    int level = -1;
    bool charging = false;
    if (GetSystemPowerStatus(&status)) {
      if (status.BatteryLifePercent != 255) {
        level = status.BatteryLifePercent;
      }
      const BYTE battery_flag = status.BatteryFlag;
      charging = status.ACLineStatus == 1 ||
                 (battery_flag != 255 && battery_flag != 128 &&
                  (battery_flag & 8) != 0);
    }
    flutter::EncodableMap info;
    info[flutter::EncodableValue("level")] = flutter::EncodableValue(level);
    info[flutter::EncodableValue("charging")] = flutter::EncodableValue(charging);
    result->Success(flutter::EncodableValue(info));
  } else if (method == fplayer_protocol::kMethodInit ||
             method == fplayer_protocol::kMethodOnLoad ||
             method == fplayer_protocol::kMethodOnUnload ||
             method == fplayer_protocol::kMethodLogLevel) {
    result->Success();
  } else if (method == fplayer_protocol::kMethodSetOrientationPortrait) {
    result->Success(flutter::EncodableValue(true));
  } else if (method == fplayer_protocol::kMethodSetOrientationLandscape) {
    result->Success(flutter::EncodableValue(false));
  } else if (method == fplayer_protocol::kMethodSetOrientationAuto ||
             method == fplayer_protocol::kMethodSetScreenOn ||
             method == fplayer_protocol::kMethodSetBrightness ||
             method == fplayer_protocol::kMethodVolumeUp ||
             method == fplayer_protocol::kMethodVolumeDown ||
             method == fplayer_protocol::kMethodVolumeMute ||
             method == fplayer_protocol::kMethodVolumeSet ||
             method == fplayer_protocol::kMethodVolUiMode ||
             method == fplayer_protocol::kMethodRequestAudioFocus ||
             method == fplayer_protocol::kMethodReleaseAudioFocus) {
    result->Success();
  } else if (method == fplayer_protocol::kMethodIsScreenKeptOn) {
    result->Success(flutter::EncodableValue(false));
  } else if (method == fplayer_protocol::kMethodBrightness ||
             method == fplayer_protocol::kMethodSystemVolume) {
    result->Success(flutter::EncodableValue(0.0));
  } else {
    result->NotImplemented();
  }
}

void FplayerPlugin::HandlePlatformMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() ==
      fplayer_protocol::kMethodGetPlatformVersion) {
    result->Success(flutter::EncodableValue(std::string("Windows")));
  } else {
    result->NotImplemented();
  }
}

void FplayerPlugin::RequestDrain() {
  if (message_hwnd_ != nullptr) {
    PostMessage(message_hwnd_, kDrainMessage, 0, 0);
  }
}

LRESULT CALLBACK FplayerPlugin::DrainWndProc(HWND hwnd, UINT message,
                                             WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }

  auto* plugin = reinterpret_cast<FplayerPlugin*>(
      GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (message == kDrainMessage && plugin != nullptr) {
    plugin->DrainPlayers();
    return 0;
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

void FplayerPlugin::DrainPlayers() {
  for (auto& entry : players_) {
    entry.second->ProcessPending();
  }
}

}
