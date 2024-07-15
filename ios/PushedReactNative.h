
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNPushedReactNativeSpec.h"

@interface PushedReactNative : NSObject <NativePushedReactNativeSpec>
#else
#import <React/RCTBridgeModule.h>

@interface PushedReactNative : NSObject <RCTBridgeModule>
#endif

@end
