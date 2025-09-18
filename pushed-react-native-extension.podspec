require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = "pushed-react-native-extension"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "12.0" }
  # Consumed via :path from the app, so the source here is irrelevant
  s.source       = { :path => "." }

  # Extension-safe sources only (no React/UIKit usage)
  s.source_files = [
    "ios/PushedExtensionHelper.swift",
    "ios/PushedCoreClient.swift"
  ]

  # No React Native dependencies here
end


