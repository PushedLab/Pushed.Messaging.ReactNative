require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

# Define the minimum iOS version supported
min_ios_version_supported = "12.0"

Pod::Spec.new do |s|
  s.name         = "pushed-react-native"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/PushedLab/Pushed.Messaging.ReactNative", :tag => "#{s.version}" }

  # Default subspec - includes everything with React Native
  s.default_subspec = 'Core'
  
  # Core subspec - full React Native integration
  s.subspec 'Core' do |core|
    core.dependency 'DeviceKit', '~> 5.0'
    core.source_files = "ios/**/*.{h,m,mm,swift}"
    core.exclude_files = "ios/PushedExtensionHelper.swift"
    
    # Use install_modules_dependencies helper to install the dependencies if React Native version >=0.71.0.
    # See https://github.com/facebook/react-native/blob/febf6b7f33fdb4904669f99d795eba4c0f95d7bf/scripts/cocoapods/new_architecture.rb#L79.
    if respond_to?(:install_modules_dependencies, true)
      install_modules_dependencies(core)
    else
      core.dependency "React-Core"

      # Don't install the dependencies when we run `pod install` in the old architecture.
      if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
        core.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
        core.pod_target_xcconfig    = {
            "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
            "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
            "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
        }
        core.dependency "React-Codegen"
        core.dependency "RCT-Folly"
        core.dependency "RCTRequired"
        core.dependency "RCTTypeSafety"
        core.dependency "ReactCommon/turbomodule/core"
      end
    end
  end
  
  # Extension subspec - only helper without React Native
  s.subspec 'Extension' do |ext|
    ext.source_files = "ios/PushedExtensionHelper.swift"
    # No React Native dependencies here
  end
end
