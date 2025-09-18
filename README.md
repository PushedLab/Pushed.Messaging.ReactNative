## Pushed React Native Package

### Overview
This package allows you to integrate the Pushed.ru push notification service into your React Native application.

### Installation Options

#### Install from GitHub
Run the following command to install the library directly from GitHub:
```bash
npm install github:PushedLab/Pushed.Messaging.ReactNative
```

Or you can specify a specific version or branch:
```bash
npm install github:PushedLab/Pushed.Messaging.ReactNative#main
npm install github:PushedLab/Pushed.Messaging.ReactNative#v0.1.7
```

### Usage Instructions
Follow these steps to use the `pushed-react-native` package in your React Native application.

#### 1. Import the Necessary Methods and Types
Import the required methods and types from the library:
```javascript
import {
  startService,
  stopService,
  PushedEventTypes,
  Push,
} from '@PushedLab/pushed-react-native';
```

#### 2. Subscribe to the `PushedEventTypes.PUSH_RECEIVED` Event
Subscribe to the `PUSH_RECEIVED` event to handle incoming push notifications:
```javascript
import React, { useEffect } from 'react';
import { NativeEventEmitter, NativeModules } from 'react-native';
import { displayNotification } from './Notifee';

useEffect(() => {
  const eventEmitter = new NativeEventEmitter(NativeModules.PushedReactNative);
  const eventListener = eventEmitter.addListener(
    PushedEventTypes.PUSH_RECEIVED,
    (push: Push) => {
      console.log(push);
      displayNotification(push.title, push.body);
    }
  );

  // Remove the listener when the component unmounts
  return () => {
    eventListener.remove();
  };
}, []);
```

#### 3. Start the Service
Use the `startService` function to start the service that handles message reception:
```javascript
const handleStart = () => {
  console.log('Starting Pushed Service');
  startService('PushedService').then((newToken) => {
    console.log(`Service has started: ${newToken}`);
  });
};
```

#### 4. Stop the Service
Use the `stopService` function to stop the service when finished:
```javascript
const handleStop = () => {
  stopService().then((message) => {
    console.log(message);
  });
};
```

#### Differences in iOS workflow

1. Messages are delivered via the APNS service and are processed by the device itself in the background. 
   startService can be called only once, to register a client token.
2. You need to configure your application to work with apns in the Pushed control panel (see the article) [https://pushed.ru/docs/apns/]
3. Make sure that the application has the Push Notifications and Background Modes -> Remote Notifications permissions

#### iOS: Notification Service Extension (confirm + SHOW)

We recommend adding a Notification Service Extension so APNs delivery is confirmed before display, and duplicates with WebSocket are avoided.

1) Podfile
Add a separate lightweight pod for the extension only:
```ruby
target 'AppNotiService' do
  pod 'pushed-react-native-extension', :path => '../node_modules/@PushedLab/pushed-react-native'
end
```

The main app target uses autolinking and pulls the core pod automatically; no manual pod is needed there.

2) Import and code in the extension (full example)
Use the helper shipped with the pod; here is a complete extension implementation:
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

        NSLog("[Extension] didReceiveNotificationRequest called with userInfo: \(request.content.userInfo)")

        // Process messageId via helper: saves to App Group and confirms delivery
        if let messageId = request.content.userInfo["messageId"] as? String {
            NSLog("[Extension] Found messageId: \(messageId), delegating to PushedIosLib")
            PushedExtensionHelper.processMessage(messageId)
        } else {
            NSLog("[Extension] No messageId found in notification")
        }

        // Always send content back to the system
        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

3) App Group (required)
- Add an App Group capability to BOTH the app target and the extension target.
- Use the same identifier, e.g. `group.ru.pushed.messaging`.
- The extension writes processed `messageId`s to the App Group store; on app startup the library merges them to avoid WS duplicates after a cold start.

4) Keychain Sharing
- Enable Keychain Sharing for both targets and keep the same access group so the extension can read the `clientToken` saved by the app.

5) Notes
- Push payload must include `messageId`.
- The library automatically merges delivered notifications and App Group entries on startup.

### Description of Methods and Types in the `pushed-react-native` Library

#### `startService(serviceName: string, applicationId?: string): Promise<string>`
This function starts the push notification service.

- **Parameters:**
  - `serviceName`: A `string` representing the name of the service to start.
  - `applicationId` *(optional)*: A `string` containing your Pushed `applicationId`. If supplied, the library will immediately initialise the client token for this application.  
    Alternatively, you can call `setApplicationId('YOUR_APP_ID')` before invoking `startService`.

- **Returns:**
  - A `Promise<string>` that resolves with the device token needed for sending push notifications. See the example.

#### `stopService(): Promise<string>`
This function stops the push notification service.

- **Returns:**
  - A `Promise<string>` that resolves with a message indicating that the service has been stopped.

#### `PushedEventTypes`
This enum contains the types of events that the Pushed.ru system works with.

- **Enum Values:**
  - `PUSH_RECEIVED`: Represents the event type for receiving a push notification.

#### `Push`
This class represents a push notification and is a wrapper over an arbitrary key-value dictionary.

- **Constructor:**
  - `constructor(data: { [key: string]: string })`
    - Creates a new instance of `Push` using the provided data.