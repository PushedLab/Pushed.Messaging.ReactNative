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

#### Setting up an iOS Notification Service Extension

To automatically confirm message delivery via the `/confirm` endpoint we recommend shipping a **Notification Service Extension** with your application. The extension intercepts the push before it is presented by the system and sends a confirmation on behalf of the user.

Steps:

1. Open your project in **Xcode** and choose `File ▸ New ▸ Target…`. Select **Notification Service Extension** under the iOS tab.
2. Pick a name, e.g. `AppNotiService`, and finish the wizard. Xcode will generate a `NotificationService.swift` file for you.
3. Replace the generated file's contents with the example located at `example/ios/AppNotiService/NotificationService.swift` or adjust it to your needs.
4. In **Signing & Capabilities** enable **Keychain Sharing** for both the **app target** and the **extension** and make sure they share the same access-group. This allows the extension to read the `clientToken` that the main app saved in the Keychain.
5. Ensure the extension is signed with the same Apple Developer **Team** and uses a bundle identifier inside your app's namespace (e.g. `com.yourapp.notification-service`).
6. Build and run. When a push arrives iOS will launch the extension, the confirmation request will be sent, and only then the notification will be shown to the user.

> Note: the push payload must contain a `messageId` field; otherwise confirmation will be skipped.

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