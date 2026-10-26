#ifndef FPLAYER_WINDOWS_FPLAYER_H_
#define FPLAYER_WINDOWS_FPLAYER_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "fplayercore.h"

namespace fplayer {

class FplayerPlugin;

struct FrameState {
  std::mutex mutex;
  std::vector<uint8_t> frame;
  int width = 0;
  int height = 0;
  std::vector<uint8_t> copy;
  FlutterDesktopPixelBuffer buffer{};
};

class FPlayer {
 public:
  FPlayer(FplayerPlugin* plugin, int id);
  ~FPlayer();

  FPlayer(const FPlayer&) = delete;
  FPlayer& operator=(const FPlayer&) = delete;

  int id() const { return id_; }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void ProcessPending();
  void OnEvent(int what, int arg1, int arg2, void* extra);
  void OnOverlay(IjkFFOverlay* overlay);
  void OnEventListen(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void OnEventCancel();

 private:
  struct PendingEvent {
    int what;
    int arg1;
    int arg2;
    std::string extra;
  };

  static void EventCallback(void* userdata, int what, int arg1, int arg2,
                            void* extra);
  static void OverlayCallback(void* userdata, IjkFFOverlay* overlay);

  void Enqueue(PendingEvent event);
  void DispatchEvent(const PendingEvent& event);
  void EmitState(int new_state);
  bool IsPlayable() const;
  void ApplyOption(int category, const std::string& key,
                   const flutter::EncodableValue& value);
  void SetupSurface(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TakeSnapshot();
  static const FlutterDesktopPixelBuffer* CopyFrame(FrameState* state,
                                                     size_t width,
                                                     size_t height);
  std::string ResolveDataSource(const std::string& url, bool* found) const;
  void Destroy();

  FplayerPlugin* plugin_;
  int id_;
  IjkFFMediaPlayer* player_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::shared_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;
  int state_ = 0;
  int width_ = 0;
  int height_ = 0;
  int rotate_ = 0;
  bool snapshot_enabled_ = false;

  std::shared_ptr<FrameState> frame_state_;

  std::mutex pending_mutex_;
  std::deque<PendingEvent> pending_events_;
  bool texture_dirty_ = false;
  std::atomic<bool> destroyed_{false};
};

}

#endif
