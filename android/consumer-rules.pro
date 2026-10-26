# ijkplayer's J4A bindings resolve classes and fields by name from native code
# during JNI_OnLoad. R8 must not remove or rename them, otherwise release builds
# fail with "JNI_ERR returned from JNI_OnLoad" as soon as a player is created.
-keep class tv.danmaku.ijk.media.player.** { *; }
-keepclassmembers class tv.danmaku.ijk.media.player.** { *; }
-dontwarn tv.danmaku.ijk.media.player.**
