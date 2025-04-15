import Multipushed from './NativeMultipushed';

export function startService(): Promise<string> {
  return Multipushed.startService();
}


export { Multipushed };
