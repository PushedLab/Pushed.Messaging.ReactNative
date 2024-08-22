#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(PushedReactNative, NSObject)


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
