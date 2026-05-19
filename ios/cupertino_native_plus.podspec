#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cupertino_native_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cupertino_native_plus'
  s.version          = '0.0.1'
  s.summary          = 'Native Liquid Glass widgets for iOS and macOS with pixel-perfect fidelity.'
  s.description      = <<-DESC
Native Liquid Glass widgets for iOS and macOS in Flutter with pixel-perfect fidelity.
                       DESC
  s.homepage         = 'https://github.com/NarekManukyan/cupertino_native_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Narek Manukyan' => 'narek.manukyan.2031@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'cupertino_native_plus/Sources/cupertino_native_plus/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'SVGKit', '~> 3.0'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'cupertino_native_plus_privacy' => ['cupertino_native_plus/Sources/cupertino_native_plus/PrivacyInfo.xcprivacy']}
end
