#
# iOS part of the Alice fork (whitecloakph/alice-wbp): forwards the iOS shake
# gesture (UIEvent motionShake, also sent by the Simulator's Device > Shake)
# to Dart. See FORK.md.
#
Pod::Spec.new do |s|
  s.name             = 'alice'
  s.version          = '2.0.0'
  s.summary          = 'Alice HTTP inspector: iOS shake gesture forwarding.'
  s.description      = <<-DESC
Forwards the iOS shake gesture to the Alice HTTP inspector.
                       DESC
  s.homepage         = 'https://github.com/whitecloakph/alice-wbp'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Alice contributors' => 'https://github.com/jhomlala/alice' }
  s.source           = { :path => '.' }
  s.source_files = 'alice/Sources/alice/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
