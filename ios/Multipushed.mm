#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <Foundation/Foundation.h>

@interface RCT_EXTERN_MODULE(Multipushed, RCTEventEmitter<RCTBridgeModule>)


RCT_EXTERN_METHOD(startService:(NSString *)serviceName
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(
                stopService: (RCTPromiseResolveBlock)resolve
                withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(
                addListener: (NSString *)eventName)

RCT_EXTERN_METHOD(removeListeners: (int)count)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
