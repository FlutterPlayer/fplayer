#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fplayer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fplayer'
  s.version          = '1.3.0'
  s.summary          = 'A video player Flutter plugin for iOS, Android and macOS.'
  s.description      = <<-DESC
A video player Flutter plugin based on ijkplayer.
                       DESC
  s.homepage         = 'https://github.com/FlutterPlayer/fplayer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FlutterPlayer' => 'bileskou@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'fplayer/Sources/fplayer/**/*.{h,m}'
  s.public_header_files = 'fplayer/Sources/fplayer/include/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.static_framework = true

  s.vendored_frameworks = 'fplayer/Frameworks/fplayercore.xcframework'

  s.frameworks = 'AudioToolbox', 'AVFoundation', 'CoreAudio', 'CoreGraphics',
                 'CoreImage', 'CoreMedia', 'CoreVideo', 'MediaPlayer',
                 'Metal', 'MetalKit', 'MobileCoreServices', 'QuartzCore',
                 'Security', 'UIKit', 'VideoToolbox'
  s.libraries = 'bz2', 'z', 'c++'

  s.ios.deployment_target = '13.0'

  # New ijkplayer kernel ships arm64 device and arm64 simulator slices.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
end
