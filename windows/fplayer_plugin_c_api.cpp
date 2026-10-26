#include "include/fplayer/fplayer_plugin.h"

#include <flutter/plugin_registrar_windows.h>

#include "fplayer_plugin.h"

void FplayerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  fplayer::FplayerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
