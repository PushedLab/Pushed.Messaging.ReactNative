import UserNotifications
import Foundation
import pushed_react_native

@objc(NotificationService)
class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        NSLog("[Extension] didReceiveNotificationRequest called with userInfo: \(request.content.userInfo)")

        // Обрабатываем messageId через основную библиотеку
        if let messageId = request.content.userInfo["messageId"] as? String {
            NSLog("[Extension] Found messageId: \(messageId), delegating to PushedIosLib")
            
            // Вызываем метод из extension-safe helper класса:
            // - Сохранит в App Group для дедупликации
            // - Отправит подтверждение на сервер
            PushedExtensionHelper.processMessage(messageId)
        } else {
            NSLog("[Extension] No messageId found in notification")
        }

        // Always send the content to system
        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        // Вызывается прямо перед тем, как система завершит работу расширения.
        // Используйте это как возможность доставить ваш "лучший" вариант измененного контента,
        // в противном случае будет использована исходная полезная нагрузка push-уведомления.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
} 
