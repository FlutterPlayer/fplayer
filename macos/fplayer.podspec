#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fplayer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'fplayer'
  s.version          = '1.3.0'
  s.summary          = 'A video player Flutter plugin for iOS, Android and macOS.'
  s.description      = <<-DESC
A video player Flutter plugin based on ijkplayer, with macOS texture support.
                       DESC
  s.homepage         = 'https://github.com/FlutterPlayer/fplayer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FlutterPlayer' => 'bileskou@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'fplayer/Sources/fplayer/**/*.{h,m}'
  s.public_header_files = 'fplayer/Sources/fplayer/include/*.h'

  s.platform = :osx, '10.15'

  s.dependency 'FlutterMacOS'

  s.vendored_frameworks = 'fplayer/Frameworks/fplayercore.xcframework'
  s.frameworks = 'AppKit', 'AVFoundation', 'AudioToolbox', 'CoreAudio',
                 'CoreGraphics', 'CoreImage', 'CoreMedia', 'CoreVideo',
                 'Foundation', 'IOKit', 'Metal', 'MetalKit', 'MetalPerformanceShaders',
                 'QuartzCore', 'Security', 'VideoToolbox'
  s.libraries = 'bz2', 'z', 'c++'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
