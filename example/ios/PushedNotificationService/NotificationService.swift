import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    // MARK: - Entry point ----------------------------------------------------

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        log("[NotificationService] didReceive called")
        
        // ➊ Рабочая копия контента
        guard let bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)
        else { 
            log("[NotificationService] Failed to create mutable content")
            return contentHandler(request.content) 
        }

        // ➋ Собираем userInfo
        var userInfo = bestAttempt.userInfo
        log("[NotificationService] Original userInfo: \(userInfo)")

        // server присылает "data":"{...}" — разворачиваем в JSON
        if let str = userInfo["data"] as? String,
           let json = try? JSONSerialization.jsonObject(
                    with: Data(str.utf8),
                    options: [.mutableContainers]) as? [AnyHashable: Any] {
            userInfo["data"] = json
            log("[NotificationService] Parsed data JSON: \(json)")
        }

        // ➌ show-/confirm-логика
        if let messageId = userInfo["messageId"] as? String {
            let clientToken = Self.clientToken()
            log("[NotificationService] Processing messageId: \(messageId), clientToken: \(clientToken ?? "nil")")
            
            confirmMessage(messageId, clientToken: clientToken)
            sendInteractionEvent(1, messageId: messageId, clientToken: clientToken) // 1 = show
        } else {
            log("[NotificationService] No messageId found in userInfo")
        }

        // ➍ (опционально) правим текст / заголовок / добавляем media
        // bestAttempt.title  = "\(bestAttempt.title) ★"
        // bestAttempt.attachments = [...]

        // ➎ Отдаём изменённый контент системе
        log("[NotificationService] Calling contentHandler")
        contentHandler(bestAttempt)
    }

    // MARK: - Housekeeping ----------------------------------------------------

    override func serviceExtensionTimeWillExpire() { 
        log("[NotificationService] serviceExtensionTimeWillExpire called")
    }

    // MARK: - Networking ------------------------------------------------------

    private func confirmMessage(_ messageId: String, clientToken: String?) {
        guard let token = clientToken else {
            log("[NotificationService] confirmMessage: no clientToken")
            return
        }
        guard let url = URL(string: "https://pub.pushed.ru/v1/confirm?transportKind=Apns") else {
            log("[NotificationService] confirmMessage: invalid URL")
            return
        }

        log("[NotificationService] confirmMessage: messageId=\(messageId), token=\(token)")
        
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let basic = Data("\(token):\(messageId)".utf8).base64EncodedString()
        r.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: r) { data, response, error in
            if let error = error {
                self.log("[NotificationService] confirmMessage error: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                let status = httpResponse.statusCode
                let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
                self.log("[NotificationService] confirmMessage response: status=\(status), body=\(responseBody)")
            }
        }
        task.resume()
    }

    private func sendInteractionEvent(_ interaction: Int,
                                      messageId: String,
                                      clientToken: String?) {
        guard let token = clientToken else {
            log("[NotificationService] sendInteractionEvent: no clientToken")
            return
        }
        guard let url = URL(string:
            "https://api.multipushed.ru/v2/mobile-push/confirm-client-interaction" +
            "?clientInteraction=\(interaction)") else {
            log("[NotificationService] sendInteractionEvent: invalid URL")
            return
        }

        log("[NotificationService] sendInteractionEvent: interaction=\(interaction), messageId=\(messageId), token=\(token)")

        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let auth = Data("\(token):\(messageId)".utf8).base64EncodedString()
        r.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")

        let body = ["clientToken": token, "messageId": messageId]
        do {
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            log("[NotificationService] sendInteractionEvent body: \(body)")
        } catch {
            log("[NotificationService] sendInteractionEvent JSON error: \(error.localizedDescription)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: r) { data, response, error in
            if let error = error {
                self.log("[NotificationService] sendInteractionEvent error: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                let status = httpResponse.statusCode
                let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
                self.log("[NotificationService] sendInteractionEvent response: status=\(status), body=\(responseBody)")
            }
        }
        task.resume()
    }

    // MARK: - Helpers ---------------------------------------------------------

    /// Получаем clientToken из стандартных UserDefaults (как в основном приложении)
    private static func clientToken() -> String? {
        return UserDefaults.standard.string(forKey: "clientToken")
    }
    
    /// Логирование (аналогично PushedIosLib)
    private func log(_ event: String) {
        print(event)
        let log = UserDefaults.standard.string(forKey: "pushedLog") ?? ""
        UserDefaults.standard.set(log + "\(Date()): \(event)\n", forKey: "pushedLog")
    }
}
