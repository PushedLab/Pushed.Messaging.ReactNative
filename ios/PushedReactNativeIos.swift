import Foundation
import React
import UIKit

@objc(PushedReactNative)
class PushedReactNative: NSObject {
  @objc(startService:withResolver:withRejecter:)
  func startService(serviceName: String,
                    resolve: @escaping RCTPromiseResolveBlock,
                    reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
        var token = ""
        if let appDelegate = UIApplication.shared.delegate {
            token = PushedIosLib.setup(appDelegate)
        }
        resolve(token);
    }
  }

  @objc(stopService:withRejecter:)
  func stopService(resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) {
        if let appDelegate = UIApplication.shared.delegate {
            PushedIosLib.stop(appDelegate)
        }
        resolve(nil)
  }

  @objc(addListener:)
  func addListener(eventName: String) {
  }

  @objc(removeListeners:)
  func removeListeners(count: Int) {
  }
}

