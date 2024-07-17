# Pushed React Native Package

## Overview

The `pushed-react-native` package allows you to integrate push notification services into your React Native application. This package provides functionalities to start and stop the push service, handle push events, and display notifications.

## Installation

To install the package, use the following command:

```bash
npm install pushed-react-native
```

## Usage

Below is an example of how to use the `pushed-react-native` package in a React Native application.

### Import the Package

First, import the necessary modules from the package:

```javascript
import {
  startService,
  stopService,
  PushedEventTypes,
  Push,
} from 'pushed-react-native';
```

### Description of Each Method and Type

#### `startService(serviceName: string): Promise<string>`

This function starts the push notification service.

- **Parameters:**
  - `serviceName`: A `string` representing the name of the service to start.

- **Returns:**
  - A `Promise<string>` that resolves with the service token when the service starts successfully.

#### `stopService(): Promise<string>`

This function stops the push notification service.

- **Returns:**
  - A `Promise<string>` that resolves with a message indicating the service has been stopped.

#### `PushedEventTypes`

This is an enum that defines the types of events related to push notifications.

- **Enum Values:**
  - `PUSH_RECEIVED`: Represents an event type for when a push notification is received.

#### `Push`

This is a class that represents a push notification.

- **Properties:**
  - `accessToken`: A `string` representing the access token.
  - `body`: A `string` containing the body of the push notification.
  - `messageId`: A `string` representing the message ID.
  - `title`: A `string` containing the title of the push notification.

- **Constructor:**
  - `constructor(data: { accessToken: string; body: string; messageId: string; title: string })`
    - Creates a new `Push` instance using the provided data.

- **Methods:**
  - `displayMessage(): string`
    - Returns a string representation of the push message.
  - `static fromStringJson(strin

