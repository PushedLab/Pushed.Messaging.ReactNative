// index.ts

import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  startService(): Promise<string>;
}

const PushedReactNative = TurboModuleRegistry.getEnforcing<Spec>('Multipushed');

export default PushedReactNative;
