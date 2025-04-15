import { NativeEventEmitter, NativeModules } from 'react-native';
import PushedReactNative from './NativeMultipushed';

export function startService(): Promise<string> {
  return PushedReactNative.startService();
}

const { Multipushed } = NativeModules;
const pushedEventEmitter = new NativeEventEmitter(Multipushed);

/**
 * Подписка на PUSH_RECEIVED
 */
export function subscribeToPush(handler: (payload: any) => void): () => void {
  const sub = pushedEventEmitter.addListener('PUSH_RECEIVED', handler);
  return () => sub.remove();
}

export { PushedReactNative, pushedEventEmitter };
export default PushedReactNative;
