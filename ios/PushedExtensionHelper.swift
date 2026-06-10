import Foundation
import Security
import UserNotifications

/// Helper class for Notification Service Extension
/// This class contains only extension-safe code without UIKit dependencies
@objc(PushedExtensionHelper)
public class PushedExtensionHelper: NSObject {
    
    // MARK: - Constants
    private static let kPushedAppGroupIdentifier = "group.ru.pushed.messaging"
    private static let clientTokenAccount = "pushed_token"
    private static let clientTokenService = "pushed_messaging_service"
    
    // MARK: - Public API for Extension
    
    /// Process messageId from Notification Service Extension
    @objc
    public static func processMessage(_ messageId: String) {
        log("[Extension] Processing messageId: \(messageId)")
        
        // 1. Save to App Group for deduplication
        saveMessageIdToAppGroup(messageId)
        
        // 2. Send confirmation to server (shared core) and only after success send SHOW
        PushedCoreClient.confirmApnsDelivery(messageId) { success in
            if success {
                // Report SHOW only after successful confirm
                PushedCoreClient.sendInteraction(1, messageId: messageId)
                log("[Extension] SHOW interaction sent after confirm for messageId: \(messageId)")
            } else {
                log("[Extension] Skipping SHOW – confirm failed for messageId: \(messageId)")
            }
        }
    }

    /// Send SHOW interaction (1) from Extension if needed by host app
    /// NOTE: Not called automatically to avoid duplicates with the main app's UNUserNotificationCenter delegate
    @objc
    public static func sendShowInteraction(_ messageId: String) {
        PushedCoreClient.sendInteraction(1, messageId: messageId)
    }

    /// Send CLICK interaction (2) from Extension if needed by host app (e.g. from Notification Content Extension)
    @objc
    public static func sendClickInteraction(_ messageId: String) {
        PushedCoreClient.sendInteraction(2, messageId: messageId)
    }

    /// Rewrites notification title/body from `pushedNotification` (priority) before the system displays the banner.
    @objc
    public static func applyDisplayContent(to content: UNMutableNotificationContent) {
        let userInfo = content.userInfo

        if let pushedNotification = userInfo["pushedNotification"] as? [String: Any] {
            if let title = stringValue(from: pushedNotification, keys: ["title", "Title"]) {
                content.title = title
            }
            if let body = stringValue(from: pushedNotification, keys: ["body", "Body"]) {
                content.body = body
            }
            if let soundName = stringValue(from: pushedNotification, keys: ["sound", "Sound"]) {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            }
            log("[Display] Applied pushedNotification: title='\(content.title)', body='\(content.body)'")
            return
        }

        // Fallback: use aps.alert only when it looks like user-facing text, not a JSON blob.
        if let aps = userInfo["aps"] as? [String: Any], let alert = aps["alert"] {
            if let alertDict = alert as? [String: Any] {
                if let title = stringValue(from: alertDict, keys: ["title", "Title"]) {
                    content.title = title
                }
                if let body = stringValue(from: alertDict, keys: ["body", "Body", "subtitle"]) {
                    content.body = body
                }
                log("[Display] Applied aps.alert dict: title='\(content.title)', body='\(content.body)'")
            } else if let alertText = alert as? String, !looksLikeJSON(alertText) {
                content.body = alertText
                log("[Display] Applied aps.alert string: body='\(content.body)'")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private static func log(_ message: String) {
        print("[PushedExtension] \(message)")
    }

    private static func stringValue(from dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let raw = dictionary[key] else { continue }
            if raw is NSNull { continue }
            guard let value = raw as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "<null>" { continue }
            return trimmed
        }
        return nil
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return false }
        return first == "{" || first == "["
    }
    
    private static func saveMessageIdToAppGroup(_ messageId: String) {
        guard let sharedDefaults = UserDefaults(suiteName: kPushedAppGroupIdentifier) else {
            log("ERROR: Cannot access App Group \(kPushedAppGroupIdentifier)")
            return
        }
        
        log("[Dedup][AppGroup] Using UserDefaults(suiteName: \(kPushedAppGroupIdentifier)) for dedup queue")
        
        let extensionKey = "pushedMessaging.extensionProcessedMessageIds"
        var processedIds = sharedDefaults.array(forKey: extensionKey) as? [String] ?? []
        
        processedIds.append(messageId)
        
        let maxIds = 10
        if processedIds.count > maxIds {
            processedIds = Array(processedIds.suffix(maxIds))
        }
        
        sharedDefaults.set(processedIds, forKey: extensionKey)
        sharedDefaults.synchronize()
        
        log("[Dedup][AppGroup] Saved messageId to suite '\(kPushedAppGroupIdentifier)': \(messageId). Total stored: \(processedIds.count)")

        // Verify write by reading back
        let verifyIds = sharedDefaults.array(forKey: extensionKey) as? [String] ?? []
        if verifyIds.contains(messageId) {
            log("[Dedup][AppGroup] Verified write OK for messageId: \(messageId) (stored count: \(verifyIds.count))")
        } else {
            log("[Dedup][AppGroup] ERROR: Write verification FAILED for messageId: \(messageId). Current stored: \(verifyIds)")
        }
    }
    
    private static func confirmMessageDelivery(_ messageId: String) {
        log("Starting message confirmation for messageId: \(messageId)")
        
        let clientToken = loadClientTokenFromKeychain()
        guard !clientToken.isEmpty else {
            log("ERROR: clientToken is empty or not found in Keychain")
            return
        }
        
        let credentials = "\(clientToken):\(messageId)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            log("ERROR: Could not encode credentials")
            return
        }
        let basicAuth = "Basic \(credentialsData.base64EncodedString())"
        
        guard let url = URL(string: "https://pub.multipushed.ru/v2/confirm?transportKind=Apns") else {
            log("ERROR: Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(basicAuth, forHTTPHeaderField: "Authorization")
        
        log("Sending confirmation request to: \(url.absoluteString)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("Request error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                log("ERROR: No HTTPURLResponse")
                return
            }
            
            let status = httpResponse.statusCode
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
            
            if (200..<300).contains(status) {
                log("SUCCESS - Status: \(status), Body: \(responseBody)")
            } else {
                log("ERROR - Status: \(status), Body: \(responseBody)")
            }
        }
        
        task.resume()
        log("Confirmation request sent for messageId: \(messageId)")
    }

    // removed: local sendInteractionEvent (delegated to PushedCoreClient)
    
    private static func loadClientTokenFromKeychain() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clientTokenAccount,
            kSecAttrService as String: clientTokenService,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            log("No clientToken found in Keychain (status: \(status))")
            return ""
        }
        
        log("Loaded clientToken from Keychain")
        return token
    }
}
