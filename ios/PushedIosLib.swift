import Foundation
import React
import UIKit

// Typealiases for method signatures
private typealias ApplicationApnsToken = @convention(c) (Any, Selector, UIApplication, Data) -> Void
private typealias IsPushedInited = @convention(c) (Any, Selector, String) -> Void
private typealias ApplicationRemoteNotification = @convention(c) (Any, Selector, UIApplication, [AnyHashable : Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void

// Global variables for the original AppDelegate
private var originalAppDelegate: UIApplicationDelegate?
private var appDelegateSubClass: AnyClass?
private var originalAppDelegateClass: AnyClass?

@objc(PushedIosLib)
public class PushedIosLib: NSProxy {
    private static var pushedToken: String?
    private static var tokenCompletion:  [(String?) -> Void] = []
    /// Returns the current client token
    public static var clientToken: String? {
        return pushedToken
    }
    
    /// Logs events (debug only)
    private static func log(_ event: String) {
        #if DEBUG
        print(event)
        let log = UserDefaults.standard.string(forKey: "pushedLog") ?? ""
        UserDefaults.standard.set(log + "\(Date()): \(event)\n", forKey: "pushedLog")
        #endif
    }
    
    /// Returns the service log (debug only)
    public static func getLog() -> String {
        return UserDefaults.standard.string(forKey: "pushedLog") ?? ""
    }
    
    /// Refreshes the pushed token
    private static func refreshPushedToken(in object: AnyObject, apnsToken: String) {
        let clientToken = UserDefaults.standard.string(forKey: "clientToken") ?? ""
        let parameters: [String: Any] = [
            "clientToken": clientToken,
            "deviceSettings": [["deviceToken": apnsToken, "transportKind": "Apns"]]
        ]
        #if DEBUG
            let url = URL(string: "https://sub.pushed.dev/tokens")!
        #else
            let url = URL(string: "https://sub.pushed.ru/tokens")!
        #endif
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            log("JSON Serialization Error: \(error.localizedDescription)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("Post Request Error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                log("Invalid Response received from the server")
                return
            }
            
            guard let responseData = data else {
                log("No Data received from the server")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String: Any] {
                    if let responseDataString = String(data: responseData, encoding: .utf8) {
                        log("Response Data: \(responseDataString)")
                    } else {
                        log("Unable to convert response data to String")
                    }
                    
                    guard let clientToken = jsonResponse["token"] as? String else {
                        log("Error with pushed token")
                        return
                    }
                    
                    UserDefaults.standard.setValue(clientToken, forKey: "clientToken")
                    PushedIosLib.pushedToken = clientToken
                    PushedIosLib.isPushedInited(didReceivePushedClientToken: clientToken)
                } else {
                    log("Data may be corrupted or in wrong format")
                    throw URLError(.badServerResponse)
                }
            } catch {
                log("JSON Parsing Error: \(error.localizedDescription)")
            }
        }
        
        // Perform the task
        task.resume()
    }
    
    /// Confirms a message by ID
    public static func confirmMessage(messageId: String, application: UIApplication, in object: AnyObject, userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let clientToken = UserDefaults.standard.string(forKey: "clientToken") ?? ""
        let loginString = String(format: "%@:%@", clientToken, messageId)
            .data(using: .utf8)!
            .base64EncodedString()
        #if DEBUG
            let url = URL(string: "https://pub.pushed.dev/v1/confirm?transportKind=Apns")!
        #else
            let url = URL(string: "https://pub.pushed.ru/v1/confirm?transportKind=Apns")!
        #endif
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Basic \(loginString)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("Post Request Error: \(error.localizedDescription)")
                redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                log("\((response as? HTTPURLResponse)?.statusCode ?? 0): Invalid Response received from the server")
                redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
                return
            }
            
            log("Message confirmed successfully")
            redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
        }
        
        // Perform the task
        task.resume()
    }
    
    /// Initializes the library
    public static func setup(_ appDelegate: UIApplicationDelegate, completion: @escaping (String?) -> Void) {
        log("Start setup")
        pushedToken = nil
        tokenCompletion.append(completion)
        proxyAppDelegate(appDelegate)
        // Requesting notification permissions which may eventually trigger token refresh
        let res = requestNotificationPermissions()
        log("Res: \(res)")
    }
    
    /// Stops the library
    public static func stop(_ appDelegate: UIApplicationDelegate) {
        log("Stop pushed")
        
        guard let appDelegate = UIApplication.shared.delegate,
              let originalClass = originalAppDelegateClass else {
            log("Cannot unproxy AppDelegate. Either AppDelegate is nil or the original class was not stored.")
            return
        }
        
        if object_setClass(appDelegate, originalClass) != nil {
            log("Successfully restored the original AppDelegate class.")
        } else {
            log("Failed to restore the original AppDelegate class.")
        }
    }
    
    /// Requests notification permissions
    static func requestNotificationPermissions() -> Bool {
        var result = true
        let center = UNUserNotificationCenter.current()
        let application = UIApplication.shared
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                log("Authorization Error: \(error)")
                result = false
                return
            }
            
            center.getNotificationSettings { settings in
                let settingsMap = [
                    "sound": settings.soundSetting == .enabled,
                    "badge": settings.badgeSetting == .enabled,
                    "alert": settings.alertSetting == .enabled
                ]
                log("Notification Settings: \(settingsMap)")
            }
        }
        
        application.registerForRemoteNotifications()
        return result
    }
    
    /// Proxies the AppDelegate
    private static func proxyAppDelegate(_ appDelegate: UIApplicationDelegate?) {
        guard let appDelegate = appDelegate else {
            log("Cannot proxy AppDelegate. Instance is nil.")
            return
        }
        
        originalAppDelegateClass = type(of: appDelegate)
        appDelegateSubClass = createSubClass(from: appDelegate)
    }
    
    /// Creates a subclass of the original AppDelegate
    private static func createSubClass(from originalDelegate: UIApplicationDelegate) -> AnyClass? {
        let originalClass = type(of: originalDelegate)
        let newClassName = "\(originalClass)_\(UUID().uuidString)"
        
        guard NSClassFromString(newClassName) == nil else {
            log("Cannot create subclass. Subclass already exists.")
            return nil
        }
        
        guard let subClass = objc_allocateClassPair(originalClass, newClassName, 0) else {
            log("Cannot create subclass.")
            return nil
        }
        
        createMethodImplementations(in: subClass, withOriginalDelegate: originalDelegate)
        
        guard class_getInstanceSize(originalClass) == class_getInstanceSize(subClass) else {
            log("Cannot create subclass. Original class and subclass sizes do not match.")
            return nil
        }
        
        objc_registerClassPair(subClass)
        if object_setClass(originalDelegate, subClass) != nil {
            log("Successfully created proxy.")
        }
        
        return subClass
    }
    
    /// Creates method implementations for the subclass
    private static func createMethodImplementations(in subClass: AnyClass, withOriginalDelegate originalDelegate: UIApplicationDelegate) {
        let originalClass = type(of: originalDelegate)
        
        let applicationApnsTokenSelector = #selector(application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
        proxyInstanceMethod(toClass: subClass, withSelector: applicationApnsTokenSelector, fromClass: PushedIosLib.self, fromSelector: applicationApnsTokenSelector, withOriginalClass: originalClass)
        
        let applicationRemoteNotificationSelector = #selector(application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
        proxyInstanceMethod(toClass: subClass, withSelector: applicationRemoteNotificationSelector, fromClass: PushedIosLib.self, fromSelector: applicationRemoteNotificationSelector, withOriginalClass: originalClass)
    }
    
    /// Proxies an instance method
    private static func proxyInstanceMethod(toClass destinationClass: AnyClass, withSelector destinationSelector: Selector, fromClass sourceClass: AnyClass, fromSelector sourceSelector: Selector, withOriginalClass originalClass: AnyClass) {
        addInstanceMethod(toClass: destinationClass, toSelector: destinationSelector, fromClass: sourceClass, fromSelector: sourceSelector)
    }
    
    /// Adds an instance method to a class
    private static func addInstanceMethod(toClass destinationClass: AnyClass, toSelector destinationSelector: Selector, fromClass sourceClass: AnyClass, fromSelector sourceSelector: Selector) {
        let method = class_getInstanceMethod(sourceClass, sourceSelector)!
        let methodImplementation = method_getImplementation(method)
        let methodTypeEncoding = method_getTypeEncoding(method)
        
        if !class_addMethod(destinationClass, destinationSelector, methodImplementation, methodTypeEncoding) {
            log("Cannot copy method to destination selector '\(destinationSelector)' as it already exists.")
        }
    }
    
    /// Gets a method implementation
    private static func methodImplementation(for selector: Selector, from fromClass: AnyClass) -> IMP? {
        guard let method = class_getInstanceMethod(fromClass, selector) else {
            return nil
        }
        return method_getImplementation(method)
    }
    
    /// Redirects the message to the original handler
    private static func redirectMessage(_ application: UIApplication, in object: AnyObject, userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        log("No original implementation of didReceiveRemoteNotification method. Skipping...")
    }
    
    /// Handles APNs token registration
    @objc
    private func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushedIosLib.log("APNs token: \(deviceToken.hexString)")
        PushedIosLib.refreshPushedToken(in: self, apnsToken: deviceToken.hexString)
    }
    
    /// Handles received remote notifications
    @objc
    private func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        PushedIosLib.log("Received message: \(userInfo)")
        
        var message = userInfo
        if let dataString = userInfo["data"] as? String {
            do {
                if let jsonData = try JSONSerialization.jsonObject(with: dataString.data(using: .utf8)!, options: .mutableContainers) as? [AnyHashable: Any] {
                    message["data"] = jsonData
                    PushedIosLib.log("Parsed data: \(jsonData)")
                }
            } catch {
                PushedIosLib.log("Data is a simple string.")
            }
        }
        
        if let messageId = userInfo["messageId"] as? String {
            PushedIosLib.log("Message ID: \(messageId)")
            PushedIosLib.confirmMessage(messageId: messageId, application: application, in: self, userInfo: message, fetchCompletionHandler: completionHandler)
        } else {
            PushedIosLib.log("No message ID found.")
            PushedIosLib.redirectMessage(application, in: self, userInfo: message, fetchCompletionHandler: completionHandler)
        }
    }
    
    /// Notifies when pushed is initialized
    @objc
    static func isPushedInited(didReceivePushedClientToken pushedToken: String) {
        PushedIosLib.log("Pushed token: \(pushedToken)")
        PushedIosLib.tokenCompletion.forEach {
            $0(pushedToken)
        }
        PushedIosLib.tokenCompletion = []
    }
}

// Extension to convert Data to a hex string
extension Data {
    var hexString: String {
        return map { String(format: "%02.2hhx", $0) }.joined()
    }
}
