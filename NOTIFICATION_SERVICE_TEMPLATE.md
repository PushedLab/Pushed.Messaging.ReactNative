# Notification Service Extension Setup

To correctly display notification titles and bodies, add the following code to your NotificationService extension. The helper automatically extracts content from `pushedNotification` (priority) with fallback to `aps.alert`:

```swift
import UserNotifications
import Foundation
import pushed_react_native_extension

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

        // IMPORTANT: Use helper to extract title/body from pushedNotification (priority over aps)
        PushedExtensionHelper.applyDisplayContent(to: bestAttemptContent)

        // Process messageId through the extension helper
        if let messageId = request.content.userInfo["messageId"] as? String {
            PushedExtensionHelper.processMessage(messageId)
        }

        // Always send the content to system
        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

## Key Points:

1. **Priority**: `pushedNotification` takes priority over `aps` for title and body
2. **Keys**: Both lowercase (`title`, `body`, `sound`) and capitalized (`Title`, `Body`, `Sound`) keys are supported in `pushedNotification`
3. **Fallback**: If `pushedNotification` is absent, `aps.alert` is used — plain strings and `{title, body}` dicts are both handled; JSON blobs in `alert` are ignored
4. **Extension Helper**: `PushedExtensionHelper.applyDisplayContent(to:)` handles all title/body extraction; `processMessage()` handles message tracking and server confirmation
