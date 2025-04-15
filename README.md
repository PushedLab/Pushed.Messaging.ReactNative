
# 📬 Multipushed React Native Module

## 🧩 Overview

This package allows you to integrate the **Multipushed** push notification service into your React Native application. It supports token registration, background/foreground message handling, and native push display even when the app is closed.

---
## 📦 Installation
Install the module from your private registry
```bash
npm install multipushed --registry=https://son.multifactor.dev:5443/repository/pushed-npm
```
Import Methods and Event Emitter

  
  

```ts
import {
startService,
pushedEventEmitter,
} from 'multipushed';
```

🔔 Subscribing to Push Events

Subscribe to the OnPushReceived event to handle incoming push notifications in JavaScript:

  
  

```ts

import React, { useEffect } from 'react';
import { pushedEventEmitter } from 'multipushed';

useEffect(() => {
	const listener = pushedEventEmitter.addListener('OnPushReceived', (data) => {
		console.log('Push received:', data);
		// Handle push data or show a custom notification
	}); 
	return () => {
		listener.remove();
	};
}, []);

```
📝 This event only fires when the app is running (foreground/background). Push notifications are still displayed natively when the app is killed.

▶️ Starting the Service
```ts

startService().then((token) => {
	console.log('Service started. Token:', token);
});

```

  
  

This initializes the native push service and registers the device token in the Multipushed backend.

🍎 iOS Notes

Messages are delivered via APNS and handled natively by the OS.

You must configure APNS tokens in the Pushed Control Panel.

  
  

Ensure the app has the following capabilities enabled in Xcode:

- Push Notifications

- Background Modes → Remote notifications

  
  

⚠️ iOS support is under development.

  
  

## 🧾 API Reference

  
  

**startService(): Promise<string>**

Starts the push service and returns the device token.

  
  

Returns:

`Promise<string>` — the token used for push delivery.

  
  

**pushedEventEmitter**

Native event emitter for receiving push events.

  
  

**Events:**

- `OnPushReceived`: emitted when a push message is received.

  
  

## 💡 Full Example

  
  

```ts

import React, { useEffect } from 'react';
import { startService, pushedEventEmitter } from 'multipushed';

export default function App() {
	useEffect(() => {
		startService().then((token) => {
			console.log('Started with token:', token);
	})

const sub = pushedEventEmitter.addListener('OnPushReceived', (data) => {
	console.log('Push received:', data);
	});
	return () => sub.remove();
}, []);
	return null;
}

```

  
  

## ✅ Platform Support

  
  

| Platform | Support |

|----------|--------------|

| Android | ✅ Supported |

| iOS | ✅ Supported  |
