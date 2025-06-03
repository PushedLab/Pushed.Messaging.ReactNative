import Foundation
import React
import UIKit

// Helper to check if we're in an app extension
private func isAppExtension() -> Bool {
    return Bundle.main.bundlePath.hasSuffix(".appex")
}

@objc(PushedReactNative)
public class PushedReactNative: RCTEventEmitter {
  @objc(startService:withResolver:withRejecter:)
  func startService(serviceName: String,
                    resolve: @escaping RCTPromiseResolveBlock,
                    reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
        var appDelegate: UIApplicationDelegate? = nil
        
        #if !APP_EXTENSION
        if !isAppExtension() {
            appDelegate = UIApplication.shared.delegate
        }
        #endif
        
        PushedIosLib.setup(appDelegate, pushedLib: self) { token in
            if let token = token {
                resolve(token);
            } else {
                resolve("Token not available yet")
            }
        }
    }
  }

  @objc(stopService:withRejecter:)
  func stopService(resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) {
        var appDelegate: UIApplicationDelegate? = nil
        
        #if !APP_EXTENSION
        if !isAppExtension() {
            appDelegate = UIApplication.shared.delegate
        }
        #endif
        
        PushedIosLib.stop(appDelegate)
        resolve(nil)
  }

  @objc(addListener:)
  override public func addListener(_ eventName: String) {
      super.addListener(eventName)
  }

  @objc(removeListeners:)
  override public func removeListeners(_ count: Double) {
      super.removeListeners(count)
  }

  override static public func moduleName() -> String! {
      return "PushedReactNative"
  }

  override public func supportedEvents() -> [String]! {
      return ["PUSH_RECEIVED"]
  }

  @objc public func sendPushReceived(_ message: String) {
      sendEvent(withName: "PUSH_RECEIVED", body: ["message": message])
  }

  override static public func requiresMainQueueSetup() -> Bool {
      return true
  }
}

