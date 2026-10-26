#include "fplayer.h"

#include <flutter/encodable_value.h>
#include <flutter/event_stream_handler_functions.h>
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "fplayer_plugin.h"
#include "fplayer_protocol.h"
#include "png_writer.h"

namespace fplayer {
namespace {

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
  if (std::holds_alternative<bool>(*value)) {
    return std::get<bool>(*value) ? 1 : 0;
  }
  return 0;
}

std::string StringValue(const flutter::EncodableValue* value) {
  if (value != nullptr && std::holds_alternative<std::string>(*value)) {
    return std::get<std::string>(*value);
  }
  return std::string();
}

std::string UrlDecode(const std::string& input) {
  std::string output;
  output.reserve(input.size());
  for (size_t i = 0; i < input.size(); ++i) {
    if (input[i] == '%' && i + 2 < input.size()) {
      const auto hex = input.substr(i + 1, 2);
      output.push_back(static_cast<char>(std::stoi(hex, nullptr, 16)));
      i += 2;
    } else {
      output.push_back(input[i]);
    }
  }
  return output;
}

void Put(flutter::EncodableMap& map, const char* key,
         flutter::EncodableValue value) {
  map[flutter::EncodableValue(std::string(key))] = std::move(value);
}

}

FPlayer::FPlayer(FplayerPlugin* plugin, int id)
    : plugin_(plugin), id_(id), frame_state_(std::make_shared<FrameState>()) {
  player_ = ijkff_create(IJK_VOUT_CALLBACK);
  if (player_ == nullptr) return;

  ijkff_set_int_option(player_, 0, "start-on-prepared",
                       IJK_OPT_CATEGORY_PLAYER);
  ijkff_set_int_option(player_, 1, "enable-position-notify",
                       IJK_OPT_CATEGORY_PLAYER);
  ijkff_set_event_cb(player_, this, &FPlayer::EventCallback);
  ijkff_set_overlay_cb(player_, this, &FPlayer::OverlayCallback);

  method_channel_ = std::make_unique<flutter::MethodChannel<
      flutter::EncodableValue>>(
      plugin_->registrar()->messenger(),
      fplayer_protocol::PlayerChannel(id_),
      &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ = std::make_unique<
      flutter::EventChannel<flutter::EncodableValue>>(
      plugin_->registrar()->messenger(),
      fplayer_protocol::PlayerEventChannel(id_),
      &flutter::StandardMethodCodec::GetInstance());
  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<
                 flutter::EventSink<flutter::EncodableValue>>&& events) {
        OnEventListen(std::move(events));
        return nullptr;
      },
      [this](const flutter::EncodableValue* arguments) {
        OnEventCancel();
        return nullptr;
      });
  event_channel_->SetStreamHandler(std::move(handler));
}

FPlayer::~FPlayer() { Destroy(); }

void FPlayer::Destroy() {
  if (destroyed_) return;
  destroyed_ = true;

  if (player_ != nullptr) {
    ijkff_set_event_cb(player_, nullptr, nullptr);
    ijkff_set_overlay_cb(player_, nullptr, nullptr);
    ijkff_shutdown(player_);
    player_ = nullptr;
  }

  if (method_channel_ != nullptr) {
    method_channel_->SetMethodCallHandler(nullptr);
  }
  if (event_channel_ != nullptr) {
    event_channel_->SetStreamHandler(nullptr);
  }
  event_sink_.reset();

  if (texture_id_ >= 0) {
    auto texture = texture_variant_;
    plugin_->registrar()->texture_registrar()->UnregisterTexture(
        texture_id_, [texture]() {});
    texture_id_ = -1;
  }
  texture_variant_.reset();
}

void FPlayer::EventCallback(void* userdata, int what, int arg1, int arg2,
                            void* extra) {
  static_cast<FPlayer*>(userdata)->OnEvent(what, arg1, arg2, extra);
}

void FPlayer::OverlayCallback(void* userdata, IjkFFOverlay* overlay) {
  static_cast<FPlayer*>(userdata)->OnOverlay(overlay);
}

void FPlayer::OnEvent(int what, int arg1, int arg2, void* extra) {
  if (destroyed_) return;
  PendingEvent event{what, arg1, arg2, std::string()};
  if (extra != nullptr) {
    event.extra = static_cast<const char*>(extra);
  }
  Enqueue(std::move(event));
}

void FPlayer::OnOverlay(IjkFFOverlay* overlay) {
  if (destroyed_ || overlay == nullptr || overlay->w <= 0 || overlay->h <= 0 ||
      overlay->pixels == nullptr || overlay->pixels[0] == nullptr) {
    return;
  }

  const int width = overlay->w;
  const int height = overlay->h;
  const int source_pitch =
      overlay->pitches != nullptr ? overlay->pitches[0] : width * 4;
  const size_t row_bytes = static_cast<size_t>(width) * 4;

  {
    std::lock_guard<std::mutex> lock(frame_state_->mutex);
    frame_state_->frame.resize(row_bytes * height);
    for (int row = 0; row < height; ++row) {
      std::memcpy(frame_state_->frame.data() + row * row_bytes,
                  overlay->pixels[0] + row * source_pitch, row_bytes);
    }
    frame_state_->width = width;
    frame_state_->height = height;
  }

  {
    std::lock_guard<std::mutex> lock(pending_mutex_);
    texture_dirty_ = true;
  }
  plugin_->RequestDrain();
}

void FPlayer::Enqueue(PendingEvent event) {
  {
    std::lock_guard<std::mutex> lock(pending_mutex_);
    pending_events_.push_back(std::move(event));
  }
  plugin_->RequestDrain();
}

void FPlayer::ProcessPending() {
  if (destroyed_) return;

  std::deque<PendingEvent> events;
  bool texture_dirty = false;
  {
    std::lock_guard<std::mutex> lock(pending_mutex_);
    events.swap(pending_events_);
    texture_dirty = texture_dirty_;
    texture_dirty_ = false;
  }

  if (texture_dirty && texture_id_ >= 0) {
    plugin_->registrar()->texture_registrar()->MarkTextureFrameAvailable(
        texture_id_);
  }

  for (const auto& event : events) {
    DispatchEvent(event);
  }
}

void FPlayer::DispatchEvent(const PendingEvent& event) {
  if (event_sink_ == nullptr) return;

  flutter::EncodableMap map;
  switch (event.what) {
    case IJK_MSG_PREPARED:
      Put(map, "event", flutter::EncodableValue(fplayer_protocol::kEventPrepared));
      Put(map, "duration",
          flutter::EncodableValue(
              static_cast<int64_t>(ijkff_get_duration(player_))));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_PLAYBACK_STATE_CHANGED:
      state_ = event.arg1;
      Put(map, "event",
          flutter::EncodableValue(fplayer_protocol::kEventStateChange));
      Put(map, "new", flutter::EncodableValue(static_cast<int32_t>(event.arg1)));
      Put(map, "old", flutter::EncodableValue(static_cast<int32_t>(event.arg2)));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_VIDEO_RENDERING_START:
    case IJK_MSG_AUDIO_RENDERING_START:
      Put(map, "event",
          flutter::EncodableValue(fplayer_protocol::kEventRenderingStart));
      Put(map, "type",
          flutter::EncodableValue(
              event.what == IJK_MSG_VIDEO_RENDERING_START ? "video"
                                                          : "audio"));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_BUFFERING_START:
    case IJK_MSG_BUFFERING_END:
      Put(map, "event", flutter::EncodableValue(fplayer_protocol::kEventFreeze));
      Put(map, "value",
          flutter::EncodableValue(event.what == IJK_MSG_BUFFERING_START));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_BUFFERING_UPDATE:
      Put(map, "event",
          flutter::EncodableValue(fplayer_protocol::kEventBuffering));
      Put(map, "head", flutter::EncodableValue(static_cast<int32_t>(event.arg1)));
      Put(map, "percent",
          flutter::EncodableValue(static_cast<int32_t>(event.arg2)));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_CURRENT_POSITION_UPDATE:
      Put(map, "event", flutter::EncodableValue(fplayer_protocol::kEventPos));
      Put(map, "pos", flutter::EncodableValue(static_cast<int32_t>(event.arg1)));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_VIDEO_ROTATION_CHANGED: {
      rotate_ = event.arg1;
      Put(map, "event", flutter::EncodableValue(fplayer_protocol::kEventRotate));
      Put(map, "degree",
          flutter::EncodableValue(static_cast<int32_t>(event.arg1)));
      event_sink_->Success(flutter::EncodableValue(map));
      if (width_ > 0 && height_ > 0) {
        flutter::EncodableMap size_map;
        Put(size_map, "event",
            flutter::EncodableValue(fplayer_protocol::kEventSizeChanged));
        const bool swapped = rotate_ == 90 || rotate_ == 270;
        Put(size_map, "width",
            flutter::EncodableValue(
                static_cast<int32_t>(swapped ? height_ : width_)));
        Put(size_map, "height",
            flutter::EncodableValue(
                static_cast<int32_t>(swapped ? width_ : height_)));
        event_sink_->Success(flutter::EncodableValue(size_map));
      }
      break;
    }
    case IJK_MSG_VIDEO_SIZE_CHANGED: {
      width_ = event.arg1;
      height_ = event.arg2;
      const bool swapped = rotate_ == 90 || rotate_ == 270;
      Put(map, "event",
          flutter::EncodableValue(fplayer_protocol::kEventSizeChanged));
      Put(map, "width",
          flutter::EncodableValue(
              static_cast<int32_t>(swapped ? height_ : width_)));
      Put(map, "height",
          flutter::EncodableValue(
              static_cast<int32_t>(swapped ? width_ : height_)));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    }
    case IJK_MSG_SEEK_COMPLETE:
      Put(map, "event",
          flutter::EncodableValue(fplayer_protocol::kEventSeekComplete));
      Put(map, "pos", flutter::EncodableValue(static_cast<int32_t>(event.arg1)));
      Put(map, "err", flutter::EncodableValue(static_cast<int32_t>(event.arg2)));
      event_sink_->Success(flutter::EncodableValue(map));
      break;
    case IJK_MSG_ERROR:
      event_sink_->Error(std::to_string(event.arg1), event.extra,
                         flutter::EncodableValue(
                             static_cast<int32_t>(event.arg2)));
      break;
    default:
      break;
  }
}

void FPlayer::EmitState(int new_state) {
  const int old_state = state_;
  state_ = new_state;
  Enqueue(PendingEvent{IJK_MSG_PLAYBACK_STATE_CHANGED, new_state, old_state,
                       std::string()});
  ProcessPending();
}

bool FPlayer::IsPlayable() const {
  return state_ == fplayer_protocol::kStateStarted ||
         state_ == fplayer_protocol::kStatePaused ||
         state_ == fplayer_protocol::kStateCompleted ||
         state_ == fplayer_protocol::kStatePrepared;
}

void FPlayer::OnEventListen(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
  event_sink_ = std::move(sink);
  ProcessPending();
}

void FPlayer::OnEventCancel() { event_sink_.reset(); }

void FPlayer::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments =
      method_call.arguments() == nullptr
          ? nullptr
          : std::get_if<flutter::EncodableMap>(method_call.arguments());
  const std::string& method = method_call.method_name();

  if (method == fplayer_protocol::kMethodSetupSurface) {
    SetupSurface(std::move(result));
  } else if (method == fplayer_protocol::kMethodSetOption) {
    if (arguments == nullptr) {
      result->Error("ArgumentError", "missing arguments");
      return;
    }
    const int64_t category =
        IntValue(FindValue(*arguments, "cat"));
    const std::string key = StringValue(FindValue(*arguments, "key"));
    const auto* long_value = FindValue(*arguments, "long");
    const auto* string_value = FindValue(*arguments, "str");
    if (long_value != nullptr) {
      ApplyOption(static_cast<int>(category), key, *long_value);
    } else if (string_value != nullptr) {
      ApplyOption(static_cast<int>(category), key, *string_value);
    }
    result->Success();
  } else if (method == fplayer_protocol::kMethodApplyOptions) {
    if (arguments != nullptr) {
      for (const auto& category_entry : *arguments) {
        if (!std::holds_alternative<int32_t>(category_entry.first) &&
            !std::holds_alternative<int64_t>(category_entry.first)) {
          continue;
        }
        const int category = static_cast<int>(IntValue(&category_entry.first));
        if (!std::holds_alternative<flutter::EncodableMap>(
                category_entry.second)) {
          continue;
        }
        for (const auto& option :
             std::get<flutter::EncodableMap>(category_entry.second)) {
          if (!std::holds_alternative<std::string>(option.first)) continue;
          ApplyOption(category, std::get<std::string>(option.first),
                      option.second);
        }
      }
    }
    result->Success();
  } else if (method == fplayer_protocol::kMethodSetDataSource) {
    if (arguments == nullptr) {
      result->Error("ArgumentError", "missing arguments");
      return;
    }
    const std::string url = StringValue(FindValue(*arguments, "url"));
    const std::string key = StringValue(FindValue(*arguments, "key"));
    bool found = false;
    const std::string path = ResolveDataSource(url, &found);
    if (!found) {
      result->Error("-875574348", "Local File not found:" + url);
      return;
    }
    if (player_ == nullptr ||
        ijkff_set_data_source(player_, path.c_str()) < 0) {
      result->Error("setDataSource", "failed to set data source");
      return;
    }
    EmitState(fplayer_protocol::kStateInitialized);
    result->Success();
  } else if (method == fplayer_protocol::kMethodPrepareAsync) {
    if (player_ == nullptr || ijkff_prepare_async(player_) < 0) {
      result->Error("prepareAsync", "failed to prepare");
      return;
    }
    result->Success();
  } else if (method == fplayer_protocol::kMethodStart) {
    if (player_ == nullptr || ijkff_start(player_) < 0) {
      result->Error("start", "failed to start");
      return;
    }
    result->Success();
  } else if (method == fplayer_protocol::kMethodPause) {
    if (!IsPlayable()) {
      result->Error("StateError", "call pause on invalid state");
      return;
    }
    ijkff_pause(player_);
    result->Success();
  } else if (method == fplayer_protocol::kMethodStop) {
    ijkff_stop(player_);
    result->Success();
  } else if (method == fplayer_protocol::kMethodReset) {
    ijkff_reset(player_);
    EmitState(fplayer_protocol::kStateIdle);
    result->Success();
  } else if (method == fplayer_protocol::kMethodGetCurrentPosition) {
    result->Success(flutter::EncodableValue(
        static_cast<int64_t>(ijkff_get_current_position(player_))));
  } else if (method == fplayer_protocol::kMethodSetVolume) {
    const auto* volume_value =
        arguments == nullptr ? nullptr : FindValue(*arguments, "volume");
    const double volume =
        volume_value != nullptr && std::holds_alternative<double>(*volume_value)
            ? std::get<double>(*volume_value)
            : 0.0;
    ijkff_set_playback_volume(player_, static_cast<float>(volume));
    result->Success();
  } else if (method == fplayer_protocol::kMethodSeekTo) {
    if (!IsPlayable()) {
      result->Error("StateError", "call seekTo on invalid state");
      return;
    }
    const int64_t position =
        arguments == nullptr ? 0 : IntValue(FindValue(*arguments, "msec"));
    ijkff_seek_to(player_, position);
    result->Success();
  } else if (method == fplayer_protocol::kMethodSetLoop) {
    const int loop =
        arguments == nullptr ? 0 : static_cast<int>(IntValue(FindValue(*arguments, "loop")));
    ijkff_set_loop(player_, loop);
    result->Success();
  } else if (method == fplayer_protocol::kMethodSetSpeed) {
    const auto* speed_value =
        arguments == nullptr ? nullptr : FindValue(*arguments, "speed");
    const double speed =
        speed_value != nullptr && std::holds_alternative<double>(*speed_value)
            ? std::get<double>(*speed_value)
            : 1.0;
    ijkff_set_speed(player_, static_cast<float>(speed));
    result->Success();
  } else if (method == fplayer_protocol::kMethodSnapshot) {
    TakeSnapshot();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void FPlayer::ApplyOption(int category, const std::string& key,
                          const flutter::EncodableValue& value) {
  if (category == 0) {
    if (key == "enable-snapshot") {
      snapshot_enabled_ = IntValue(&value) > 0;
    }
    return;
  }

  if (std::holds_alternative<int32_t>(value) ||
      std::holds_alternative<int64_t>(value) ||
      std::holds_alternative<bool>(value)) {
    ijkff_set_int_option(player_, IntValue(&value), key.c_str(), category);
  } else if (std::holds_alternative<std::string>(value)) {
    ijkff_set_option(player_, std::get<std::string>(value).c_str(), key.c_str(),
                     category);
  }
}

void FPlayer::SetupSurface(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (texture_id_ >= 0) {
    result->Success(flutter::EncodableValue(texture_id_));
    return;
  }

  auto frame_state = frame_state_;
  auto texture = std::make_shared<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [frame_state](size_t width, size_t height) {
            return CopyFrame(frame_state.get(), width, height);
          }));
  texture_id_ = plugin_->registrar()->texture_registrar()->RegisterTexture(
      texture.get());
  texture_variant_ = texture;
  result->Success(flutter::EncodableValue(texture_id_));
}

const FlutterDesktopPixelBuffer* FPlayer::CopyFrame(FrameState* state,
                                                    size_t width,
                                                    size_t height) {
  std::lock_guard<std::mutex> lock(state->mutex);
  if (state->frame.empty()) return nullptr;

  state->copy = state->frame;
  state->buffer.buffer = state->copy.data();
  state->buffer.width = static_cast<size_t>(state->width);
  state->buffer.height = static_cast<size_t>(state->height);
  state->buffer.release_callback = nullptr;
  state->buffer.release_context = nullptr;
  return &state->buffer;
}

void FPlayer::TakeSnapshot() {
  std::vector<uint8_t> frame;
  int width = 0;
  int height = 0;
  {
    std::lock_guard<std::mutex> lock(frame_state_->mutex);
    frame = frame_state_->frame;
    width = frame_state_->width;
    height = frame_state_->height;
  }

  if (frame.empty() || width <= 0 || height <= 0) {
    method_channel_->InvokeMethod(
        fplayer_protocol::kMethodOnSnapshot,
        std::make_unique<flutter::EncodableValue>(
            std::string("snapshot error")));
    return;
  }

  std::vector<uint8_t> png;
  if (!EncodePng(frame, width, height, &png) || png.empty()) {
    method_channel_->InvokeMethod(
        fplayer_protocol::kMethodOnSnapshot,
        std::make_unique<flutter::EncodableValue>(
            std::string("snapshot error")));
    return;
  }

  flutter::EncodableMap result;
  Put(result, "data", flutter::EncodableValue(png));
  Put(result, "w", flutter::EncodableValue(static_cast<int32_t>(width)));
  Put(result, "h", flutter::EncodableValue(static_cast<int32_t>(height)));
  method_channel_->InvokeMethod(
      fplayer_protocol::kMethodOnSnapshot,
      std::make_unique<flutter::EncodableValue>(std::move(result)));
}

std::string FPlayer::ResolveDataSource(const std::string& url,
                                       bool* found) const {
  *found = false;
  const std::string asset_prefix = "asset://";
  const std::string file_prefix = "file://";

  if (url.rfind(asset_prefix, 0) == 0) {
    std::string rest = url.substr(asset_prefix.size());
    std::string key;
    if (!rest.empty() && rest[0] != '/') {
      const auto slash = rest.find('/');
      const std::string package = rest.substr(0, slash);
      const std::string path =
          slash == std::string::npos ? std::string() : rest.substr(slash + 1);
      key = "packages/" + package + "/" + path;
    } else {
      while (!rest.empty() && rest[0] == '/') rest.erase(0, 1);
      key = rest;
    }

    wchar_t executable[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, executable, MAX_PATH);
    const auto asset_path =
        std::filesystem::path(executable).parent_path() / "data" /
        "flutter_assets" / std::filesystem::u8path(key);
    if (std::filesystem::exists(asset_path)) {
      *found = true;
      return asset_path.u8string();
    }
    return std::string();
  }

  if (url.rfind(file_prefix, 0) == 0) {
    const auto path = std::filesystem::u8path(
        UrlDecode(url.substr(file_prefix.size())));
    *found = std::filesystem::exists(path);
    return path.u8string();
  }

  if (url.find("://") != std::string::npos) {
    *found = true;
    return url;
  }

  const auto path = std::filesystem::u8path(url);
  *found = std::filesystem::exists(path);
  return path.u8string();
}

}
