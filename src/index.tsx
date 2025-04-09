import Multipushed from './NativeMultipushed';

// export function multiply(a: number, b: number): number {
//   return Multipushed.multiply(a, b);
// }

export function startService(): Promise<string> {
  return Multipushed.startService();
}

// export function start() {
//   return Multipushed.start();
// }

// export function initialize(): Promise<boolean> {
//   return Multipushed.initialize();
// }
