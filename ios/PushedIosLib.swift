import Foundation
import React
import UIKit
import UserNotifications
import Security // Added for Keychain access

// Typealiases for method signatures
private typealias ApplicationApnsToken = @convention(c) (Any, Selector, UIApplication, Data) -> Void
private typealias IsPushedInited = @convention(c) (Any, Selector, String) -> Void
private typealias ApplicationRemoteNotification = @convention(c) (Any, Selector, UIApplication, [AnyHashable : Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void

// Global variables for the original AppDelegate
private var originalAppDelegate: UIApplicationDelegate?
private var appDelegateSubClass: AnyClass?
private var originalAppDelegateClass: AnyClass?

// Helper to check if we're in an app extension
private func isAppExtension() -> Bool {
    return Bundle.main.bundlePath.hasSuffix(".appex")
}

@objc(PushedIosLib)
public class PushedIosLib: NSObject, UNUserNotificationCenterDelegate {
    private static var pushedToken: String?
    private static var tokenCompletion:  [(String?) -> Void] = []
    private static var pushedLib: PushedReactNative?
    private static var shownMessageIds: Set<String> = []
    
    // MARK: - Keychain helpers

    private static let clientTokenKey = "com.pushed.clientToken"

    /// Saves token string to Keychain (replaces existing value if any)
    private static func saveClientTokenToKeychain(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        // Delete existing item first (if any)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clientTokenKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clientTokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            log("ClientToken saved to Keychain")
            print("[Pushed] ClientToken saved to Keychain: \(token.prefix(10))...")
            let verified = loadClientTokenFromKeychain()
            print("[Pushed] ClientToken read back from Keychain: \(verified.prefix(10))... (len: \(verified.count))")
        } else {
            log("ERROR: Unable to save clientToken to Keychain. OSStatus: \(status)")
        }
    }

    /// Loads token string from Keychain, returns empty string if not found
    private static func loadClientTokenFromKeychain() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clientTokenKey,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            return ""
        }
        return token
    }

    /// Returns the current client token
    public static var clientToken: String? {
        return pushedToken
    }
    
    /// Retrieves clientToken from Keychain
    private static func getClientToken() -> String {
        let keychainToken = loadClientTokenFromKeychain()
        if !keychainToken.isEmpty {
            return keychainToken
        }

        // Fallback to in-memory cached value
        return pushedToken ?? ""
    }
    
    /// Logs events (debug only)
    private static func log(_ event: String) {
        print(event)
        let log = UserDefaults.standard.string(forKey: "pushedLog") ?? ""
        UserDefaults.standard.set(log + "\(Date()): \(event)\n", forKey: "pushedLog")
    }
    
    /// Returns the service log (debug only)
    public static func getLog() -> String {
        return UserDefaults.standard.string(forKey: "pushedLog") ?? ""
    }
    
    /// Refreshes the pushed token
    private static func refreshPushedToken(in object: AnyObject, apnsToken: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let permissionGranted = settings.authorizationStatus == .authorized
            let clientToken = getClientToken()
            let parameters: [String: Any] = [
                "clientToken": clientToken,
                "deviceSettings": [[
                    "deviceToken": apnsToken,
                    "transportKind": "Apns",
                    "displayPushNotificationsPermission": permissionGranted,
                    "operatingSystem": "ios"
                ]]
            ]
            log("[Token] Sending parameters: \(parameters)")
            let url = URL(string: "https://sub.pushed.ru/tokens")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                if let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                    log("[Token] HTTP body: \(bodyString)")
                }
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
                        saveClientTokenToKeychain(clientToken)
                        
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
    }
    
    /// Confirms a message by ID
    /// NOTE: This function is now disabled in the main app and only works in NotificationService extension
    /*
    public static func confirmMessage(messageId: String, application: UIApplication, in object: AnyObject, userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let clientToken = getClientToken()
        let loginString = String(format: "%@:%@", clientToken, messageId)
            .data(using: .utf8)!
            .base64EncodedString()
        guard let url = URL(string: "https://pub.pushed.ru/v1/confirm?transportKind=Apns") else {
            log("Invalid URL for confirming message")
            redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
            return
        }
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
            
            if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                log("Confirm response data: \(responseString)")
            }
            
            log("Message confirmed successfully")
            redirectMessage(application, in: object, userInfo: userInfo, fetchCompletionHandler: completionHandler)
        }
        
        // Perform the task
        task.resume()
    }
    */
    
    /// Initializes the library
    public static func setup(
        _ appDelegate: UIApplicationDelegate?,
        pushedLib: PushedReactNative?,
        completion: @escaping (String?) -> Void) {
        log("Start setup")
        pushedToken = nil
        tokenCompletion.append(completion)
        
        // Only proxy AppDelegate if we're not in an app extension
        if !isAppExtension(), let appDelegate = appDelegate {
            proxyAppDelegate(appDelegate)
        } else {
            log("Skipping AppDelegate proxy - running in app extension or no delegate available")
        }
        
        PushedIosLib.pushedLib = pushedLib
        
        // Set UNUserNotificationCenter delegate - это критически важно для отслеживания нажатий!
        UNUserNotificationCenter.current().delegate = sharedDelegate
        log("UNUserNotificationCenter delegate set to PushedIosLib.sharedDelegate")
        
        // Request notification permissions
        if !isAppExtension() {
            let res = requestNotificationPermissions()
            log("Res: \(res)")
        } else {
            log("Skipping notification permissions request - running in app extension")
        }
    }
    
    /// Stops the library
    public static func stop(_ appDelegate: UIApplicationDelegate?) {
        log("Stop pushed")
        
        // Skip if in app extension
        if isAppExtension() {
            log("Skipping stop - running in app extension")
            return
        }
        
        #if !APP_EXTENSION
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
        #endif
    }
    
    /// Requests notification permissions
    static func requestNotificationPermissions() -> Bool {
        var result = true
        let center = UNUserNotificationCenter.current()
        
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
        
        #if !APP_EXTENSION
        UIApplication.shared.registerForRemoteNotifications()
        #else
        log("Skipping remote notifications registration - running in app extension")
        #endif
        
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

    private static func convertObjectToJSON(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else {
            print("Invalid JSON object")
            return nil
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch let error {
            print("Error converting object to JSON: \(error)")
            return nil
        }
    }

    /// Redirects the message to the original handler   
    private static func redirectMessage(_ application: UIApplication, in object: AnyObject, userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        log("[Native] Push received in background/foreground - processing natively only")
        log("[Native] UserInfo: \(userInfo)")
        log("[Native] Message confirmation is handled by NotificationService extension")
        
        
        log("[Native] Calling completion handler with .newData")
        completionHandler(.newData)
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
            // NOTE: confirmMessage is now handled only by NotificationService extension
            PushedIosLib.log("Message confirmation will be handled by NotificationService extension")
        } else {
            PushedIosLib.log("No message ID found.")
        }
        
        // Always redirect to handle the message natively only
        PushedIosLib.redirectMessage(application, in: self, userInfo: message, fetchCompletionHandler: completionHandler)
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

    /// Sends interaction event to the server
    private static func sendInteractionEvent(_ interaction: Int, userInfo: [AnyHashable: Any]) {
        let interactionName = interaction == 1 ? "SHOW" : (interaction == 2 ? "CLICK" : "UNKNOWN(\(interaction))")
        log("[Interaction] Starting \(interactionName) event")
        
        guard let messageId = userInfo["messageId"] as? String else {
            log("[Interaction] ERROR: No messageId in userInfo: \(userInfo)")
            return
        }
        
        let clientToken = getClientToken()
        if clientToken.isEmpty {
            log("[Interaction] ERROR: clientToken is empty")
            return
        }
        
        let urlString = "https://api.pushed.ru/v2/mobile-push/confirm-client-interaction?clientInteraction=\(interaction)"
        log("[Interaction] \(interactionName): messageId=\(messageId), clientToken=\(clientToken.prefix(10))..., url=\(urlString)")
        
        guard let url = URL(string: urlString) else {
            log("[Interaction] ERROR: Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let basicAuth = "Basic " + Data("\(clientToken):\(messageId)".utf8).base64EncodedString()
        log("[Interaction] \(interactionName): Authorization header created")
        request.addValue(basicAuth, forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "clientToken": clientToken,
            "messageId": messageId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            log("[Interaction] \(interactionName): Request body created successfully")
        } catch {
            log("[Interaction] ERROR: JSON Serialization Error: \(error.localizedDescription)")
            return
        }
        
        log("[Interaction] \(interactionName): Sending HTTP request...")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("[Interaction] \(interactionName): Request error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                log("[Interaction] \(interactionName): ERROR: No HTTPURLResponse")
                return
            }
            
            let status = httpResponse.statusCode
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
            
            if (200...299).contains(status) {
                log("[Interaction] \(interactionName): SUCCESS - Status: \(status), Body: \(responseBody)")
            } else {
                log("[Interaction] \(interactionName): ERROR - Status: \(status), Body: \(responseBody)")
            }
        }
        
        task.resume()
        log("[Interaction] \(interactionName): HTTP task started")
    }

    // MARK: - UNUserNotificationCenterDelegate

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        PushedIosLib.log("[UNDelegate] willPresent called with userInfo: \(userInfo)")
        
        if let messageId = userInfo["messageId"] as? String {
            PushedIosLib.log("[UNDelegate] Found messageId: \(messageId)")
            if !Self.shownMessageIds.contains(messageId) {
                PushedIosLib.log("[UNDelegate] Sending SHOW event for messageId: \(messageId)")
                PushedIosLib.sendInteractionEvent(1, userInfo: userInfo) // Show
                Self.shownMessageIds.insert(messageId)
                PushedIosLib.log("[UNDelegate] SHOW event sent and messageId added to shown set")
            } else {
                PushedIosLib.log("[UNDelegate] SHOW event already sent for messageId: \(messageId)")
            }
        } else {
            PushedIosLib.log("[UNDelegate] WARNING: No messageId found in userInfo")
        }
        
        PushedIosLib.log("[UNDelegate] Calling completionHandler with [.alert, .sound, .badge]")
        completionHandler([.alert, .sound, .badge])
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        PushedIosLib.log("[UNDelegate] didReceive called with response actionIdentifier: \(response.actionIdentifier)")
        PushedIosLib.log("[UNDelegate] didReceive userInfo: \(userInfo)")
        
        if let messageId = userInfo["messageId"] as? String {
            PushedIosLib.log("[UNDelegate] Found messageId: \(messageId)")
            
            // Отправляем SHOW если еще не отправляли
            if !Self.shownMessageIds.contains(messageId) {
                PushedIosLib.log("[UNDelegate] Sending SHOW event for messageId: \(messageId) (from didReceive)")
                PushedIosLib.sendInteractionEvent(1, userInfo: userInfo) // Show
                Self.shownMessageIds.insert(messageId)
                PushedIosLib.log("[UNDelegate] SHOW event sent and messageId added to shown set")
            } else {
                PushedIosLib.log("[UNDelegate] SHOW event already sent for messageId: \(messageId)")
            }
            
            // Всегда отправляем CLICK при нажатии
            PushedIosLib.log("[UNDelegate] Sending CLICK event for messageId: \(messageId)")
            PushedIosLib.sendInteractionEvent(2, userInfo: userInfo) // Click
            PushedIosLib.log("[UNDelegate] CLICK event sent for messageId: \(messageId)")
        } else {
            PushedIosLib.log("[UNDelegate] WARNING: No messageId found in userInfo")
        }
        
        PushedIosLib.log("[UNDelegate] Calling completionHandler")
        completionHandler()
    }
    

    // Singleton delegate for UNUserNotificationCenter
    private static let sharedDelegate: PushedIosLib = {
        return PushedIosLib()
    }()

    public override init() {
        super.init()
    }
}

// Extension to convert Data to a hex string
extension Data {
    var hexString: String {
        return map { String(format: "%02.2hhx", $0) }.joined()
    }
}

