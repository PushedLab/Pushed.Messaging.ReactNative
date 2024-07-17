
## Pushed React Native Package

### Overview
This package allows you to integrate the Pushed.ru push notification service into your React Native application.

### Usage Instructions
Follow these steps to use the `pushed-react-native` package in your React Native application.

#### 1. Install the Library
Run the following command to install the library:
```bash
npm install pushed-react-native --registry=https://son.multifactor.dev:5443/repository/pushed-npm
```

#### 2. Import the Necessary Methods and Types
Import the required methods and types from the library:
```javascript
import {
  startService,
  stopService,
  PushedEventTypes,
  Push,
} from 'pushed-react-native';
```

#### 3. Subscribe to the `PushedEventTypes.PUSH_RECEIVED` Event
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

#### 4. Start the Foreground Service
Use the `startService` function to start the foreground service that handles message reception:
```javascript
const handleStart = () => {
  console.log('Starting Pushed Service');
  startService('PushedService').then((newToken) => {
    console.log(`Service has started: ${newToken}`);
  });
};
```

### 5. Stop the Foreground Service
Use the `stopService` function to stop the foreground service when finished:
```javascript
const handleStop = () => {
  stopService().then((message) => {
    console.log(message);
  });
};
```

### Description of Methods and Types in the `pushed-react-native` Library

#### `startService(serviceName: string): Promise<string>`
This function starts the push notification service.

- **Parameters:**
  - `serviceName`: A `string` representing the name of the service to start.

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
