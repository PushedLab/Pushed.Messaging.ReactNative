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

export function startService(serviceName: string, applicationId: string = ''): Promise<string> {
  return PushedReactNative.startService(serviceName, applicationId);
}

export function stopService(): Promise<string> {
  return PushedReactNative.stopService();
}

// Функция для автоматической инициализации сервиса
export function initializePushedService(): Promise<string> {
  return startService('PushedService');
}

export enum PushedEventTypes {
  PUSH_RECEIVED = 'PUSH_RECEIVED',
}

export class Push {
  [key: string]: any;

  constructor(data: { [key: string]: any }) {
    Object.assign(this, data);
  }
}

// Позволяет задать applicationId до запуска сервиса
export function setApplicationId(applicationId: string): void {
  PushedReactNative.setApplicationId(applicationId);
}
