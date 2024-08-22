import Foundation
import React
import UIKit

private typealias ApplicationApnsToken = @convention(c) (Any, Selector, UIApplication, Data) -> Void
private typealias IsPushedInited = @convention(c) (Any, Selector, String) -> Void
private typealias ApplicationRemoteNotification = @convention(c) (Any, Selector, UIApplication, [AnyHashable : Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void

private var gOriginalAppDelegate: UIApplicationDelegate?
private var gAppDelegateSubClass: AnyClass?

@objc(PushedReactNative)
class PushedReactNative: NSObject {
  @objc(startService:withResolver:withRejecter:)
  func startService(serviceName: String, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
        if let appDelegate = UIApplication.shared.delegate {
            PushedIosLib.setup(appDelegate)
        }
    }
    resolve(serviceName);
  }

  @objc(stopService:withRejecter:)
  func stopService(resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) {
    resolve(nil);
  }

  @objc(addListener:)
  func addListener(eventName: String) {
  }

  @objc(removeListeners:)
  func removeListeners(count: Int) {
  }
}


@objc(PushedIosLib)
public class PushedIosLib: NSProxy {
  private static var pushedToken: String?
  /// Return current client token
  public static var clientToken: String? {
      return pushedToken
  }
  private static func addLog(_ event: String){
#if DEBUG
    print(event)
    let log=UserDefaults.standard.string(forKey: "pushedLog") ?? ""
    UserDefaults.standard.set(log+"\(Date()): \(event)\n", forKey: "pushedLog")
#endif
  }
  
  ///Returns the service log(debug only)
  public static func getLog() -> String {
      return UserDefaults.standard.string(forKey: "pushedLog") ?? ""
  }

  private static func refreshPushedToken(in object: AnyObject, apnsToken: String){
      let clientToken=UserDefaults.standard.string(forKey: "clientToken") ?? ""
      let parameters: [String: Any] = ["clientToken": clientToken, "deviceSettings": [["deviceToken": apnsToken, "transportKind": "Apns"]]]
      let url = URL(string: "https://sub.pushed.ru/tokens")!
      let session = URLSession.shared
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.addValue("application/json", forHTTPHeaderField: "Accept")
      do {
          request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
      } catch let error {
          addLog(error.localizedDescription)
          return
      }
      let task = session.dataTask(with: request) { data, response, error in
          if let error = error {
              addLog("Post Request Error: \(error.localizedDescription)")
              return
          }
          guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
          else {
              addLog("Invalid Response received from the server")
              return
          }
          guard let responseData = data else {
              addLog("nil Data received from the server")
              return
          }
          do {
              if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String: Any] {
                  guard let clientToken=jsonResponse["token"] as? String else{
                      addLog("Some wrong with pushed token")
                      return
                  }
                  UserDefaults.standard.setValue(clientToken, forKey: "clientToken")
                  PushedIosLib.pushedToken=clientToken
                  PushedIosLib.isPushedInited(didRecievePushedClientToken: clientToken)
              } else {
                  addLog("data maybe corrupted or in wrong format")
                  throw URLError(.badServerResponse)
              }
          } catch let error {
              addLog(error.localizedDescription)
          }
      }
      // perform the task
      task.resume()
  }
  
  public static func confirmMessage(messageId: String, application: UIApplication, in object: AnyObject, userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void){
    
      let clientToken=UserDefaults.standard.string(forKey: "clientToken") ?? ""
      let loginString = String(format: "%@:%@", clientToken, messageId).data(using: String.Encoding.utf8)!.base64EncodedString()
      let url = URL(string: "https://pub.pushed.ru/v1/confirm?transportKind=Apns")!
      let session = URLSession.shared
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.addValue("application/json", forHTTPHeaderField: "Accept")
      request.setValue("Basic \(loginString)", forHTTPHeaderField: "Authorization")
      let task = session.dataTask(with: request) { data, response, error in
          if let error = error {
              addLog("Post Request Error: \(error.localizedDescription)")
              PushedIosLib.redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
              return
          }
          guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
          else {
              addLog("\((response as? HTTPURLResponse)?.statusCode ?? 0): Invalid Response received from the server")
              PushedIosLib.redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
              return
          }
          addLog("Message confirm done")
          PushedIosLib.redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
      }
      // perform the task
      task.resume()
      
  }
  ///Init librarry
  public static func setup(_ appDel: UIApplicationDelegate) {
      addLog("Start setup")
      pushedToken=nil
      proxyAppDelegate(appDel)
      let res=requestNotificationPermissions()
      addLog("Res: \(res)")
  }
  
  static func requestNotificationPermissions() -> Bool {

    var result=true;
    let center = UNUserNotificationCenter.current()
    let application = UIApplication.shared
          
    center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
        if let error = error {
            addLog("Err: \(error)")
            result=false
            return
        }
        center.getNotificationSettings { (settings) in
            let map = [
                "sound": settings.soundSetting == .enabled,
                "badge": settings.badgeSetting == .enabled,
                "alert": settings.alertSetting == .enabled,
            ]
            addLog("Settings: \(map)")
        }
    }
    application.registerForRemoteNotifications()
    return result
  }
  //------------------------------
  private static func proxyAppDelegate(_ appDelegate: UIApplicationDelegate?) {
      guard let appDelegate = appDelegate else {
          addLog("Cannot proxy AppDelegate. Instance is nil.")
          return
      }

      gAppDelegateSubClass = createSubClass(from: appDelegate)
      //self.reassignAppDelegate()
  }

  private static func createSubClass(from originalDelegate: UIApplicationDelegate) -> AnyClass? {
      let originalClass = type(of: originalDelegate)
      let newClassName = "\(originalClass)_\(UUID().uuidString)"

      guard NSClassFromString(newClassName) == nil else {
          addLog("Cannot create subclass. Subclass already exists.")
          return nil
      }

      guard let subClass = objc_allocateClassPair(originalClass, newClassName, 0) else {
          addLog("Cannot create subclass. Subclass already exists.")
          return nil
      }

      self.createMethodImplementations(in: subClass, withOriginalDelegate: originalDelegate)
      
      guard class_getInstanceSize(originalClass) == class_getInstanceSize(subClass) else {
          addLog("Cannot create subclass. Original class' and subclass' sizes do not match.")
          return nil
      }

      objc_registerClassPair(subClass)
      if object_setClass(originalDelegate, subClass) != nil {
          addLog("Successfully created proxy.")
      }

      return subClass
  }
  private static func createMethodImplementations(
              in subClass: AnyClass,
              withOriginalDelegate originalDelegate: UIApplicationDelegate)
  {
      let originalClass = type(of: originalDelegate)

      let applicationApnsTokeneSelector = #selector(application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
      self.proxyInstanceMethod(
          toClass: subClass,
          withSelector: applicationApnsTokeneSelector,
          fromClass: PushedIosLib.self,
          fromSelector: applicationApnsTokeneSelector,
          withOriginalClass: originalClass)
      
      let applicationRemoteNotification = #selector(application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
      self.proxyInstanceMethod(
          toClass: subClass,
          withSelector: applicationRemoteNotification,
          fromClass: PushedIosLib.self,
          fromSelector: applicationRemoteNotification,
          withOriginalClass: originalClass)
  }
  
  
  
  private static func proxyInstanceMethod(
              toClass destinationClass: AnyClass,
              withSelector destinationSelector: Selector,
              fromClass sourceClass: AnyClass,
              fromSelector sourceSelector: Selector,
              withOriginalClass originalClass: AnyClass)
  {
      self.addInstanceMethod(
                  toClass: destinationClass,
                  toSelector: destinationSelector,
                  fromClass: sourceClass,
                  fromSelector: sourceSelector)

  }
  
  private static func addInstanceMethod(
              toClass destinationClass: AnyClass,
              toSelector destinationSelector: Selector,
              fromClass sourceClass: AnyClass,
              fromSelector sourceSelector: Selector)
  {
      let method = class_getInstanceMethod(sourceClass, sourceSelector)!
      let methodImplementation = method_getImplementation(method)
      let methodTypeEncoding = method_getTypeEncoding(method)

      if !class_addMethod(destinationClass, destinationSelector, methodImplementation, methodTypeEncoding) {
          addLog("Cannot copy method to destination selector '\(destinationSelector)' as it already exists.")
      }
  }

  private static func methodImplementation(for selector: Selector, from fromClass: AnyClass) -> IMP? {
          print(fromClass)
          print(selector)
          guard let method = class_getInstanceMethod(fromClass, selector) else {
              return nil
          }

          return method_getImplementation(method)
      }

  private static func redirectMessage(_ application: UIApplication, in object: AnyObject, userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void){
    addLog("No original implementation didReceiveRemoteNotification method. Skipping...")
  }
  
  @objc
  private func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      PushedIosLib.addLog("Apns token: \(deviceToken.hexString)")
      PushedIosLib.refreshPushedToken(in: self, apnsToken: deviceToken.hexString)
  }

  @objc
  private func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      PushedIosLib.addLog("Message: \(userInfo)")
      var message=userInfo
      if let data=userInfo["data"] as? String {
          do{
              if let jsonResponse = try JSONSerialization.jsonObject(with: data.data(using: .utf8)!, options: .mutableContainers) as? [AnyHashable: Any] {
                  message["data"]=jsonResponse
                  PushedIosLib.addLog("Data: \(jsonResponse)")
              }
          } catch {
              PushedIosLib.addLog(" Data is String")
          }
      }
      if let messageId=userInfo["messageId"] as? String {
          PushedIosLib.addLog("MessageId: \(messageId)")
          PushedIosLib.confirmMessage(messageId: messageId, application: application, in: self, userInfo: message, fetchCompletionHandler: completionHandler)
      }
      else {
          PushedIosLib.addLog("No messageId")
          PushedIosLib.redirectMessage(application, in: self, userInfo: message, fetchCompletionHandler: completionHandler)
      }
      
  }
  
  @objc
  static func isPushedInited(didRecievePushedClientToken pushedToken: String) {
      PushedIosLib.addLog("Pushed token " + pushedToken)
  }
}

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}
