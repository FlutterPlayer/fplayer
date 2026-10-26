// MIT License
//
// Copyright (c) [2019] [Befovy]
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "FplayerPlugin.h"
#import "FPlayer.h"
#import "FQueuingEventSink.h"

#import <CoreAudio/CoreAudio.h>
#import <FlutterMacOS/FlutterMacOS.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <math.h>
#import "FPlayerProtocol.h"

typedef NS_ENUM(int, FijkVoUIMode) {
    hideUIWhenPlayable = 0,
    hideUIWhenPlaying,
    neverShowUI,
    alwaysShowUI,
};

@interface FplayerPlugin ()

- (void)onPlayingChange:(int)delta;
- (void)onPlayableChange:(int)delta;
- (void)setScreenOn:(BOOL)on;
- (void)handleVolumeChanged;

@end

static OSStatus FPlayerVolumePropertyListener(
    AudioObjectID inObjectID, UInt32 inNumberAddresses,
    const AudioObjectPropertyAddress inAddresses[], void *inClientData) {
    FplayerPlugin *plugin = (__bridge FplayerPlugin *)inClientData;
    [plugin handleVolumeChanged];
    return noErr;
}

static AudioDeviceID FPlayerDefaultOutputDevice(void) {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        0,
    };
    AudioDeviceID device = kAudioObjectUnknown;
    UInt32 size = sizeof(device);
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &address, 0, NULL, &size,
                                                 &device);
    return status == noErr ? device : kAudioObjectUnknown;
}

static BOOL FPlayerGetDeviceVolume(AudioDeviceID device, Float32 *volume) {
    if (device == kAudioObjectUnknown || volume == NULL) {
        return NO;
    }
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        0,
    };
    UInt32 size = sizeof(Float32);
    if (AudioObjectHasProperty(device, &address)) {
        Float32 value = 0;
        if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size,
                                       &value) == noErr) {
            *volume = value;
            return YES;
        }
    }

    Float32 sum = 0;
    int count = 0;
    for (UInt32 channel = 1; channel <= 2; channel++) {
        address.mElement = channel;
        if (!AudioObjectHasProperty(device, &address)) {
            continue;
        }
        Float32 value = 0;
        size = sizeof(Float32);
        if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size,
                                       &value) == noErr) {
            sum += value;
            count++;
        }
    }
    if (count > 0) {
        *volume = sum / count;
        return YES;
    }
    return NO;
}

static BOOL FPlayerSetDeviceVolume(AudioDeviceID device, Float32 volume) {
    if (device == kAudioObjectUnknown) {
        return NO;
    }
    volume = fmaxf(0.0f, fminf(1.0f, volume));

    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        0,
    };
    Boolean settable = false;
    UInt32 size = sizeof(Float32);
    if (AudioObjectHasProperty(device, &address) &&
        AudioObjectIsPropertySettable(device, &address, &settable) == noErr &&
        settable) {
        if (AudioObjectSetPropertyData(device, &address, 0, NULL, size,
                                       &volume) == noErr) {
            return YES;
        }
    }

    BOOL changed = NO;
    for (UInt32 channel = 1; channel <= 2; channel++) {
        address.mElement = channel;
        settable = false;
        size = sizeof(Float32);
        if (!AudioObjectHasProperty(device, &address)) {
            continue;
        }
        if (AudioObjectIsPropertySettable(device, &address, &settable) != noErr ||
            !settable) {
            continue;
        }
        if (AudioObjectSetPropertyData(device, &address, 0, NULL, size,
                                       &volume) == noErr) {
            changed = YES;
        }
    }
    return changed;
}

@implementation FplayerPlugin {
    id<FlutterPluginRegistrar> _registrar;
    NSMutableDictionary<NSNumber *, FPlayer *> *_fPlayers;

    FQueuingEventSink *_eventSink;
    FlutterEventChannel *_eventChannel;

    int _volumeUIMode;
    BOOL _eventListening;
    BOOL _showOsUI;
    BOOL _screenOn;
    id<NSObject> _activity;

    AudioDeviceID _listenedDevice;
    BOOL _volumeListenerAttached;
    Float32 _lastVolume;
    BOOL _hasLastVolume;
}

static FplayerPlugin *_instance = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel =
        [FlutterMethodChannel methodChannelWithName:FPLAYER_CHANNEL_PLUGIN
                                    binaryMessenger:[registrar messenger]];
    FplayerPlugin *instance = [[FplayerPlugin alloc] initWithRegistrar:registrar];
    _instance = instance;
    [registrar addMethodCallDelegate:instance channel:channel];

    // The package's FplayerPlatform uses this channel for version information.
    FlutterMethodChannel *platformChannel =
        [FlutterMethodChannel methodChannelWithName:FPLAYER_CHANNEL_PLATFORM
                                    binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:platformChannel];
}

+ (FplayerPlugin *)singleInstance {
    return _instance;
}

- (instancetype)initWithRegistrar:
    (NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    if (self) {
        _registrar = registrar;
        _fPlayers = [[NSMutableDictionary alloc] init];
        _eventListening = NO;
        _volumeUIMode = alwaysShowUI;
        _showOsUI = YES;
        _screenOn = NO;
        _listenedDevice = kAudioObjectUnknown;
        _volumeListenerAttached = NO;
        _hasLastVolume = NO;
        _eventSink = [[FQueuingEventSink alloc] init];

        _eventChannel =
            [FlutterEventChannel eventChannelWithName:FPLAYER_CHANNEL_PLUGIN_EVENT
                                      binaryMessenger:[registrar messenger]];
        [_eventChannel setStreamHandler:self];
    }
    return self;
}

- (void)dealloc {
    if (_activity != nil) {
        [[NSProcessInfo processInfo] endActivity:_activity];
        _activity = nil;
    }
    [self detachVolumeListener];
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
    NSDictionary *argsMap = call.arguments;
    if ([FPLAYER_METHOD_GET_PLATFORM_VERSION isEqualToString:call.method]) {
        NSString *osVersion = [[NSProcessInfo processInfo]
            operatingSystemVersionString];
        result([@"macOS " stringByAppendingString:osVersion]);
    } else if ([FPLAYER_METHOD_INIT isEqualToString:call.method]) {
        result(nil);
    } else if ([FPLAYER_METHOD_CREATE_PLAYER isEqualToString:call.method]) {
        FPlayer *fplayer = [[FPlayer alloc] initWithRegistrar:_registrar];
        NSNumber *playerId = fplayer.playerId;
        _fPlayers[playerId] = fplayer;
        result(playerId);
    } else if ([FPLAYER_METHOD_RELEASE_PLAYER isEqualToString:call.method]) {
        NSNumber *pid = argsMap[@"pid"];
        FPlayer *fPlayer = [_fPlayers objectForKey:pid];
        [fPlayer shutdown];
        if (fPlayer != nil) {
            [_fPlayers removeObjectForKey:pid];
        }
        result(nil);
    } else if ([FPLAYER_METHOD_GET_BATTERY_INFO isEqualToString:call.method]) {
        result([self batteryInfo]);
    } else if ([FPLAYER_METHOD_LOG_LEVEL isEqualToString:call.method]) {
        // ijkplayer's macOS framework does not expose a public log level API.
        result(nil);
    } else if ([FPLAYER_METHOD_SET_ORIENTATION_PORTRAIT isEqualToString:call.method] ||
               [FPLAYER_METHOD_SET_ORIENTATION_LANDSCAPE isEqualToString:call.method]) {
        result(@(NO));
    } else if ([FPLAYER_METHOD_SET_ORIENTATION_AUTO isEqualToString:call.method]) {
        result(nil);
    } else if ([FPLAYER_METHOD_SET_SCREEN_ON isEqualToString:call.method]) {
        NSNumber *on = argsMap[@"on"];
        [self setScreenOn:on == nil ? NO : on.boolValue];
        result(nil);
    } else if ([FPLAYER_METHOD_IS_SCREEN_KEPT_ON isEqualToString:call.method]) {
        result(@(_screenOn));
    } else if ([FPLAYER_METHOD_BRIGHTNESS isEqualToString:call.method]) {
        result(@(1.0));
    } else if ([FPLAYER_METHOD_SET_BRIGHTNESS isEqualToString:call.method]) {
        result(nil);
    } else if ([FPLAYER_METHOD_VOLUME_UP isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"step"];
        float step = number == nil ? 1.0 / 16.0 : [number floatValue];
        float vol = [self getSystemVolume];
        result(@([self setSystemVolume:vol + step]));
    } else if ([FPLAYER_METHOD_VOLUME_DOWN isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"step"];
        float step = number == nil ? 1.0 / 16.0 : [number floatValue];
        float vol = [self getSystemVolume];
        result(@([self setSystemVolume:vol - step]));
    } else if ([FPLAYER_METHOD_VOLUME_MUTE isEqualToString:call.method]) {
        result(@([self setSystemVolume:0.0f]));
    } else if ([FPLAYER_METHOD_VOLUME_SET isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"vol"];
        float vol = number == nil ? [self getSystemVolume] : [number floatValue];
        result(@([self setSystemVolume:vol]));
    } else if ([FPLAYER_METHOD_SYSTEM_VOLUME isEqualToString:call.method]) {
        result(@([self getSystemVolume]));
    } else if ([FPLAYER_METHOD_VOL_UI_MODE isEqualToString:call.method]) {
        NSNumber *number = argsMap[@"mode"];
        _volumeUIMode = number == nil ? alwaysShowUI : [number intValue];
        _showOsUI = _volumeUIMode == alwaysShowUI;
        result(nil);
    } else if ([FPLAYER_METHOD_ON_LOAD isEqualToString:call.method]) {
        _eventListening = YES;
        [self attachVolumeListener];
        result(nil);
    } else if ([FPLAYER_METHOD_ON_UNLOAD isEqualToString:call.method]) {
        _eventListening = NO;
        [self detachVolumeListener];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)onPlayingChange:(int)delta {
    _playingCnt += delta;
}

- (void)onPlayableChange:(int)delta {
    _playableCnt += delta;
}

- (NSDictionary *)batteryInfo {
    int level = -1;
    BOOL charging = NO;
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (info != NULL) {
        NSArray *sources = (__bridge_transfer NSArray *)IOPSCopyPowerSourcesList(info);
        for (id source in sources) {
            NSDictionary *desc = (__bridge NSDictionary *)IOPSGetPowerSourceDescription(
                info, (__bridge CFTypeRef)source);
            if (desc == nil) continue;
            NSNumber *current = desc[@kIOPSCurrentCapacityKey];
            NSNumber *max = desc[@kIOPSMaxCapacityKey];
            if (current != nil && max != nil && max.intValue > 0) {
                level = (int)((double)current.intValue * 100.0 / max.intValue);
                charging = [desc[@kIOPSIsChargingKey] boolValue] ||
                           [desc[@kIOPSIsChargedKey] boolValue];
                break;
            }
        }
        CFRelease(info);
    }
    return @{@"level" : @(level), @"charging" : @(charging)};
}

- (void)setScreenOn:(BOOL)on {
    if (on == _screenOn) {
        return;
    }
    _screenOn = on;
    if (on) {
        if (_activity == nil) {
            _activity = [[NSProcessInfo processInfo]
                beginActivityWithOptions:(NSActivityUserInitiated |
                                          NSActivityIdleSystemSleepDisabled)
                                  reason:@"fplayer playback"];
        }
    } else {
        if (_activity != nil) {
            [[NSProcessInfo processInfo] endActivity:_activity];
            _activity = nil;
        }
    }
}

- (float)getSystemVolume {
    Float32 volume = 0;
    AudioDeviceID device = FPlayerDefaultOutputDevice();
    if (FPlayerGetDeviceVolume(device, &volume)) {
        return volume;
    }
    return 0.0f;
}

- (float)setSystemVolume:(float)volume {
    volume = fmaxf(0.0f, fminf(1.0f, volume));
    AudioDeviceID device = FPlayerDefaultOutputDevice();
    FPlayerSetDeviceVolume(device, volume);

    Float32 current = volume;
    FPlayerGetDeviceVolume(device, &current);
    [self sendVolumeChange:current];
    return current;
}

- (void)attachVolumeListener {
    if (_volumeListenerAttached) {
        return;
    }
    _listenedDevice = FPlayerDefaultOutputDevice();
    if (_listenedDevice == kAudioObjectUnknown) {
        return;
    }
    for (UInt32 element = 0; element <= 2; element++) {
        AudioObjectPropertyAddress address = {
            kAudioDevicePropertyVolumeScalar,
            kAudioDevicePropertyScopeOutput,
            element,
        };
        if (!AudioObjectHasProperty(_listenedDevice, &address)) {
            continue;
        }
        AudioObjectAddPropertyListener(_listenedDevice, &address,
                                       FPlayerVolumePropertyListener,
                                       (__bridge void *)self);
    }
    _volumeListenerAttached = YES;
}

- (void)detachVolumeListener {
    if (!_volumeListenerAttached ||
        _listenedDevice == kAudioObjectUnknown) {
        _volumeListenerAttached = NO;
        return;
    }
    for (UInt32 element = 0; element <= 2; element++) {
        AudioObjectPropertyAddress address = {
            kAudioDevicePropertyVolumeScalar,
            kAudioDevicePropertyScopeOutput,
            element,
        };
        if (!AudioObjectHasProperty(_listenedDevice, &address)) {
            continue;
        }
        AudioObjectRemovePropertyListener(_listenedDevice, &address,
                                          FPlayerVolumePropertyListener,
                                          (__bridge void *)self);
    }
    _volumeListenerAttached = NO;
    _listenedDevice = kAudioObjectUnknown;
}

- (void)handleVolumeChanged {
    Float32 volume = 0;
    AudioDeviceID device = FPlayerDefaultOutputDevice();
    if (device != _listenedDevice) {
        [self detachVolumeListener];
        _listenedDevice = device;
        [self attachVolumeListener];
    }
    if (!FPlayerGetDeviceVolume(device, &volume)) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendVolumeChange:volume];
    });
}

- (void)sendVolumeChange:(float)value {
    if (!_eventListening) {
        return;
    }
    if (_hasLastVolume && fabsf(_lastVolume - value) < 0.001f) {
        return;
    }
    _lastVolume = value;
    _hasLastVolume = YES;
    [_eventSink success:@{
        @"event" : FPLAYER_EVENT_VOLUME,
        @"sui" : @(_showOsUI),
        @"vol" : @(value)
    }];
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
    [_eventSink setDelegate:nil];
    return nil;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:
                                           (nonnull FlutterEventSink)events {
    [_eventSink setDelegate:events];
    return nil;
}

@end
