#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <Foundation/Foundation.h>

@interface RCT_EXTERN_MODULE(PushedReactNative, RCTEventEmitter<RCTBridgeModule>)


RCT_EXTERN_METHOD(startService:(NSString *)serviceName
                 applicationId:(NSString *)applicationId
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(
                stopService: (RCTPromiseResolveBlock)resolve
                withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(
                addListener: (NSString *)eventName)

RCT_EXTERN_METHOD(removeListeners: (int)count)

RCT_EXTERN_METHOD(setApplicationId:(NSString *)applicationId)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
