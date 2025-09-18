import Foundation
import Security

@objc(PushedCoreClient)
public class PushedCoreClient: NSObject {
    private static func log(_ message: String) {
        print("[PushedCore] \(message)")
    }

    // Shared Keychain identifiers (same as in PushedIosLib)
    private static let clientTokenAccount = "pushed_token"
    private static let clientTokenService = "pushed_messaging_service"

    /// Load client token from Keychain (shared between app and extension)
    @objc
    public static func loadClientTokenFromKeychain() -> String {
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

        return token
    }

    /// Confirm APNs delivery (used by Notification Service Extension)
    @objc
    public static func confirmApnsDelivery(_ messageId: String) {
        confirmApnsDelivery(messageId) { _ in }
    }

    /// Confirm APNs delivery with completion flag (success/failure)
    public static func confirmApnsDelivery(_ messageId: String, completion: @escaping (Bool) -> Void) {
        log("Confirming APNs delivery for messageId: \(messageId)")

        let clientToken = loadClientTokenFromKeychain()
        guard !clientToken.isEmpty else {
            log("ERROR: clientToken is empty")
            completion(false)
            return
        }

        let credentials = "\(clientToken):\(messageId)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            log("ERROR: Could not encode credentials")
            completion(false)
            return
        }
        let basicAuth = "Basic \(credentialsData.base64EncodedString())"

        guard let url = URL(string: "https://pub.multipushed.ru/v2/confirm?transportKind=Apns") else {
            log("ERROR: Invalid confirm URL")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(basicAuth, forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("Confirm request error: \(error.localizedDescription)")
                completion(false)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                log("ERROR: No HTTPURLResponse")
                completion(false)
                return
            }
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
            if (200...299).contains(http.statusCode) {
                log("Confirm APNs SUCCESS: status=\(http.statusCode), body=\(body)")
                completion(true)
            } else {
                log("Confirm APNs ERROR: status=\(http.statusCode), body=\(body)")
                completion(false)
            }
        }

        task.resume()
    }

    /// Send client interaction (1=SHOW, 2=CLICK)
    @objc
    public static func sendInteraction(_ interaction: Int, messageId: String) {
        guard interaction == 1 || interaction == 2 else {
            log("ERROR: Unsupported interaction value: \(interaction)")
            return
        }
        let interactionName = interaction == 1 ? "SHOW" : "CLICK"
        log("Starting \(interactionName) interaction for messageId: \(messageId)")

        let clientToken = loadClientTokenFromKeychain()
        guard !clientToken.isEmpty else {
            log("ERROR: clientToken is empty")
            return
        }

        let urlString = "https://api.multipushed.ru/v2/mobile-push/confirm-client-interaction?clientInteraction=\(interaction)"
        guard let url = URL(string: urlString) else {
            log("ERROR: Invalid interaction URL: \(urlString)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let basicAuth = "Basic " + Data("\(clientToken):\(messageId)".utf8).base64EncodedString()
        request.addValue(basicAuth, forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "clientToken": clientToken,
            "messageId": messageId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            log("ERROR: JSON Serialization Error: \(error.localizedDescription)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log("\(interactionName) request error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                log("ERROR: No HTTPURLResponse")
                return
            }

            let status = httpResponse.statusCode
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"

            if (200...299).contains(status) {
                log("\(interactionName) SUCCESS - Status: \(status), Body: \(responseBody)")
            } else {
                log("\(interactionName) ERROR - Status: \(status), Body: \(responseBody)")
            }
        }

        task.resume()
    }
}


