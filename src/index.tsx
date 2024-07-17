import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'pushed-react-native' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const PushedReactNative = NativeModules.PushedReactNative
  ? NativeModules.PushedReactNative
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function startService(serviceName: string): Promise<string> {
  return PushedReactNative.startService(serviceName);
}

export function stopService(): Promise<string> {
  return PushedReactNative.stopService();
}

export enum PushedEventTypes {
  PUSH_RECEIVED = 'PUSH_RECEIVED',
}

export class Push {
  accessToken: string;
  body: string;
  messageId: string;
  title: string;

  constructor(data: {
    accessToken: string;
    body: string;
    messageId: string;
    title: string;
  }) {
    this.accessToken = data.accessToken;
    this.body = data.body;
    this.messageId = data.messageId;
    this.title = data.title;
  }

  displayMessage(): string {
    return `Title: ${this.title}, Body: ${this.body}`;
  }

  static fromStringJson(stringJson: string): Push {
    const jsonData = JSON.parse(stringJson);
    return new Push(jsonData);
  }
}
