# Pushed React Native Example

This is an example project demonstrating how to use the `@PushedLab/pushed-react-native` package for integrating push notifications from Pushed.ru into your React Native application.

## Installing the Package

### Option 1: Install from GitHub
You can install the package directly from GitHub:

```bash
npm install github:PushedLab/Pushed.Messaging.ReactNative
```

Or specify a specific version or branch:
```bash
npm install github:PushedLab/Pushed.Messaging.ReactNative#main
npm install github:PushedLab/Pushed.Messaging.ReactNative#v0.1.7
```

### Option 2: Use Local Version
For development, you can link to a local version by adding this to your package.json:

```json
"dependencies": {
  "@PushedLab/pushed-react-native": "file:/path/to/Pushed.Messaging.ReactNative"
}
```

Then run `npm install` or `yarn` to install the package.

## Usage in Your App

To implement automatic service initialization in your own app, use this pattern:

```typescript
import { useEffect, useState } from 'react';
import { startService, PushedEventTypes } from '@PushedLab/pushed-react-native';

export default function App() {
  const [token, setToken] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Auto-start the service
    startService('PushedService')
      .then((newToken) => {
        setToken(newToken);
        setIsLoading(false);
      })
      .catch((error) => {
        console.error('Failed to start service:', error);
        setIsLoading(false);
      });
  }, []);

  // Your app UI here...
}
```

---

This is a new [**React Native**](https://reactnative.dev) project, bootstrapped using [`@react-native-community/cli`](https://github.com/react-native-community/cli).

# Getting Started

>**Note**: Make sure you have completed the [React Native - Environment Setup](https://reactnative.dev/docs/environment-setup) instructions till "Creating a new application" step, before proceeding.

## Step 1: Start the Metro Server

First, you will need to start **Metro**, the JavaScript _bundler_ that ships _with_ React Native.

To start Metro, run the following command from the _root_ of your React Native project:

```bash
# using npm
npm start

# OR using Yarn
yarn start
```

## Step 2: Start your Application

Let Metro Bundler run in its _own_ terminal. Open a _new_ terminal from the _root_ of your React Native project. Run the following command to start your _Android_ or _iOS_ app:

### For Android

```bash
# using npm
npm run android

# OR using Yarn
yarn android
```

### For iOS

```bash
# using npm
npm run ios

# OR using Yarn
yarn ios
```

If everything is set up _correctly_, you should see your new app running in your _Android Emulator_ or _iOS Simulator_ shortly provided you have set up your emulator/simulator correctly.

This is one way to run your app — you can also run it directly from within Android Studio and Xcode respectively.

## Step 3: Modifying your App

Now that you have successfully run the app, let's modify it.

1. Open `App.tsx` in your text editor of choice and edit some lines.
2. For **Android**: Press the <kbd>R</kbd> key twice or select **"Reload"** from the **Developer Menu** (<kbd>Ctrl</kbd> + <kbd>M</kbd> (on Window and Linux) or <kbd>Cmd ⌘</kbd> + <kbd>M</kbd> (on macOS)) to see your changes!

   For **iOS**: Hit <kbd>Cmd ⌘</kbd> + <kbd>R</kbd> in your iOS Simulator to reload the app and see your changes!

## Congratulations! :tada:

You've successfully run and modified your React Native App. :partying_face:

### Now what?

- If you want to add this new React Native code to an existing application, check out the [Integration guide](https://reactnative.dev/docs/integration-with-existing-apps).
- If you're curious to learn more about React Native, check out the [Introduction to React Native](https://reactnative.dev/docs/getting-started).

# Troubleshooting

If you can't get this to work, see the [Troubleshooting](https://reactnative.dev/docs/troubleshooting) page.

# Learn More

To learn more about React Native, take a look at the following resources:

- [React Native Website](https://reactnative.dev) - learn more about React Native.
- [Getting Started](https://reactnative.dev/docs/environment-setup) - an **overview** of React Native and how setup your environment.
- [Learn the Basics](https://reactnative.dev/docs/getting-started) - a **guided tour** of the React Native **basics**.
- [Blog](https://reactnative.dev/blog) - read the latest official React Native **Blog** posts.
- [`@facebook/react-native`](https://github.com/facebook/react-native) - the Open Source; GitHub **repository** for React Native.
