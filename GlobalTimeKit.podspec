Pod::Spec.new do |s|
  s.name         = 'GlobalTimeKit'
  s.version      = '1.1.2'
  s.summary      = 'Lightweight NTP client for Swift. Get accurate server time on Apple platforms.'
  s.homepage     = 'https://github.com/dimayurkovski/GlobalTimeKit'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Dima Yurkovski' => 'dima.yurkovski@gmail.com' }
  s.source       = { :git => 'https://github.com/dimayurkovski/GlobalTimeKit.git', :tag => s.version.to_s }

  s.swift_versions = ['5.9', '5.10', '6.0']

  s.ios.deployment_target     = '16.0'
  s.osx.deployment_target     = '13.0'
  s.tvos.deployment_target    = '16.0'
  s.watchos.deployment_target = '9.0'

  s.source_files = 'Sources/*.swift'
  s.frameworks   = 'Foundation', 'Network'
  s.resource_bundles = { 'GlobalTimeKit' => ['Sources/PrivacyInfo.xcprivacy'] }
end
