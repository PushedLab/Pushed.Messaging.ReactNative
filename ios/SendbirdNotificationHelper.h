//
//  SendbirdNotificationHelper.h
//
//  Created by Airen Kang on 2024/02/20.
//  Copyright © 2024 Sendbird. All rights reserved.
//

typedef void (^ErrorHandler)(NSError * _Nullable error);

NS_ASSUME_NONNULL_BEGIN

@interface SendbirdNotificationHelper : NSObject

+ (void)markPushNotificationAsDelivered:(NSDictionary *)remoteNotificationPayload
                     completionHandler:(nullable ErrorHandler)completionHandler;

+ (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

+ (void)setAppGroup:(NSString *)suiteName;

@end

NS_ASSUME_NONNULL_END
