import Foundation
import Security

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
        
        // 2. Send confirmation to server (shared core)
        PushedCoreClient.confirmApnsDelivery(messageId)
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
    
    // MARK: - Private Methods
    
    private static func log(_ message: String) {
        print("[PushedExtension] \(message)")
    }
    
    private static func saveMessageIdToAppGroup(_ messageId: String) {
        guard let sharedDefaults = UserDefaults(suiteName: kPushedAppGroupIdentifier) else {
            log("ERROR: Cannot access App Group \(kPushedAppGroupIdentifier)")
            return
        }
        
        let extensionKey = "pushedMessaging.extensionProcessedMessageIds"
        var processedIds = sharedDefaults.array(forKey: extensionKey) as? [String] ?? []
        
        processedIds.append(messageId)
        
        let maxIds = 100
        if processedIds.count > maxIds {
            processedIds = Array(processedIds.suffix(maxIds))
        }
        
        sharedDefaults.set(processedIds, forKey: extensionKey)
        sharedDefaults.synchronize()
        
        log("Saved messageId to App Group: \(messageId). Total stored: \(processedIds.count)")
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
