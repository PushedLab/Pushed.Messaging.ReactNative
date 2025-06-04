//
//  NotificationService.m
//  AppNotiService
//
//  Created by Sergei Golov on 03.06.25.
//

#import "NotificationService.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    NSLog(@"[Extension] didReceiveNotificationRequest called with userInfo: %@", request.content.userInfo);
    
    // Send SHOW interaction event
    [self sendInteractionEvent:1 withUserInfo:request.content.userInfo];
    
    // Confirm the message if messageId is present
    NSString *messageId = request.content.userInfo[@"messageId"];
    if (messageId && [messageId isKindOfClass:[NSString class]]) {
        NSLog(@"[Extension] Confirming message with ID: %@", messageId);
        [self confirmMessage:messageId withUserInfo:request.content.userInfo];
    } else {
        NSLog(@"[Extension] No messageId found for confirmation");
    }
    
    // Modify the notification content here...
    self.bestAttemptContent.title = [NSString stringWithFormat:@"%@ [modified]", self.bestAttemptContent.title];
    
    NSLog(@"[Extension] Content modified, calling contentHandler");
    self.contentHandler(self.bestAttemptContent);
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

// MARK: - Message Confirmation

- (void)confirmMessage:(NSString *)messageId withUserInfo:(NSDictionary *)userInfo {
    NSLog(@"[Extension Confirm] Starting message confirmation for messageId: %@", messageId);
    
    // Get clientToken from shared UserDefaults
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.pushed.example"];
    NSString *clientToken = [sharedDefaults stringForKey:@"clientToken"];
    
    // Fallback to file if UserDefaults fails
    if (!clientToken || clientToken.length == 0) {
        NSURL *sharedURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pushed.example"];
        if (sharedURL) {
            NSURL *tokenFileURL = [sharedURL URLByAppendingPathComponent:@"clientToken.txt"];
            NSError *error;
            clientToken = [NSString stringWithContentsOfURL:tokenFileURL encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"[Extension Confirm] ERROR: Could not read clientToken from file: %@", error.localizedDescription);
            }
        }
    }
    
    if (!clientToken || clientToken.length == 0) {
        NSLog(@"[Extension Confirm] ERROR: clientToken is empty, cannot confirm message");
        return;
    }
    
    NSLog(@"[Extension Confirm] Using clientToken: %@...", [clientToken substringToIndex:MIN(10, clientToken.length)]);
    
    // Create Basic Auth: clientToken:messageId
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", clientToken, messageId];
    NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    NSString *basicAuth = [NSString stringWithFormat:@"Basic %@", [credentialsData base64EncodedStringWithOptions:0]];
    
    // Create URL and request
    NSString *urlString = @"https://pub.pushed.ru/v1/confirm?transportKind=Apns";
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"[Extension Confirm] ERROR: Invalid URL: %@", urlString);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:basicAuth forHTTPHeaderField:@"Authorization"];
    
    NSLog(@"[Extension Confirm] Sending confirmation request to: %@", urlString);
    NSLog(@"[Extension Confirm] Authorization header created for messageId: %@", messageId);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[Extension Confirm] Request error: %@", error.localizedDescription);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (!httpResponse) {
            NSLog(@"[Extension Confirm] ERROR: No HTTPURLResponse");
            return;
        }
        
        NSInteger status = httpResponse.statusCode;
        NSString *responseBody = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<no body>";
        
        if (status >= 200 && status < 300) {
            NSLog(@"[Extension Confirm] SUCCESS - Status: %ld, Body: %@", (long)status, responseBody);
        } else {
            NSLog(@"[Extension Confirm] ERROR - Status: %ld, Body: %@", (long)status, responseBody);
        }
    }];
    
    [task resume];
    NSLog(@"[Extension Confirm] Confirmation request sent for messageId: %@", messageId);
}

// MARK: - Interaction Events

- (void)sendInteractionEvent:(NSInteger)interaction withUserInfo:(NSDictionary *)userInfo {
    NSString *interactionName = interaction == 1 ? @"SHOW" : (interaction == 2 ? @"CLICK" : [NSString stringWithFormat:@"UNKNOWN(%ld)", (long)interaction]);
    NSLog(@"[Extension Interaction] === Starting %@ event ===", interactionName);
    NSLog(@"[Extension Interaction] UserInfo received: %@", userInfo);
    
    NSString *messageId = userInfo[@"messageId"];
    NSLog(@"[Extension Interaction] MessageId extracted: %@", messageId ?: @"<nil>");
    
    if (!messageId || ![messageId isKindOfClass:[NSString class]]) {
        NSLog(@"[Extension Interaction] ERROR: No messageId in userInfo: %@", userInfo);
        return;
    }
    
    // Use shared UserDefaults with app group to access clientToken
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.pushed.example"];
    NSLog(@"[Extension Interaction] SharedDefaults created: %@", sharedDefaults ? @"SUCCESS" : @"FAILED");
    
    if (sharedDefaults) {
        // Debug: list all keys in shared UserDefaults
        NSDictionary *sharedDict = [sharedDefaults dictionaryRepresentation];
        NSLog(@"[Extension Interaction] All keys in shared UserDefaults: %@", sharedDict.allKeys);
        NSLog(@"[Extension Interaction] Shared UserDefaults content: %@", sharedDict);
        
        // Test: check for test value
        NSString *testValue = [sharedDefaults stringForKey:@"testSharing"];
        NSLog(@"[Extension Interaction] TEST: Test value retrieved: %@", testValue ?: @"<nil>");
    }
    
    NSString *clientToken = [sharedDefaults stringForKey:@"clientToken"];
    NSLog(@"[Extension Interaction] ClientToken retrieved: %@", clientToken ? [clientToken substringToIndex:MIN(10, clientToken.length)] : @"<nil>");
    
    // Also try standard UserDefaults as fallback
    NSString *standardToken = [[NSUserDefaults standardUserDefaults] stringForKey:@"clientToken"];
    NSLog(@"[Extension Interaction] Standard UserDefaults clientToken: %@", standardToken ? [standardToken substringToIndex:MIN(10, standardToken.length)] : @"<nil>");
    
    // Alternative: Try reading from shared file
    if (!clientToken || clientToken.length == 0) {
        NSLog(@"[Extension Interaction] FILE: Attempting to read clientToken from shared file...");
        
        // Try shared container first
        NSURL *sharedURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pushed.example"];
        if (sharedURL) {
            NSURL *tokenFileURL = [sharedURL URLByAppendingPathComponent:@"clientToken.txt"];
            NSError *error;
            NSString *fileToken = [NSString stringWithContentsOfURL:tokenFileURL encoding:NSUTF8StringEncoding error:&error];
            if (fileToken && !error) {
                clientToken = fileToken;
                NSLog(@"[Extension Interaction] FILE: ClientToken read from shared file: %@", [clientToken substringToIndex:MIN(10, clientToken.length)]);
            } else {
                NSLog(@"[Extension Interaction] FILE: ERROR reading from shared file: %@", error.localizedDescription);
            }
        } else {
            NSLog(@"[Extension Interaction] FILE: Could not access shared container");
        }
        
        // Fallback: try Documents directory (this probably won't work from extension, but let's try)
        if (!clientToken || clientToken.length == 0) {
            NSArray *documentsURLs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
            if (documentsURLs.count > 0) {
                NSURL *documentsURL = documentsURLs[0];
                NSURL *tokenFileURL = [documentsURL URLByAppendingPathComponent:@"pushed_clientToken.txt"];
                NSError *error;
                NSString *fileToken = [NSString stringWithContentsOfURL:tokenFileURL encoding:NSUTF8StringEncoding error:&error];
                if (fileToken && !error) {
                    clientToken = fileToken;
                    NSLog(@"[Extension Interaction] FILE: ClientToken read from Documents fallback: %@", [clientToken substringToIndex:MIN(10, clientToken.length)]);
                } else {
                    NSLog(@"[Extension Interaction] FILE: ERROR reading from Documents fallback: %@", error.localizedDescription);
                }
            }
        }
    }
    
    if (!clientToken || clientToken.length == 0) {
        NSLog(@"[Extension Interaction] ERROR: clientToken is empty from shared UserDefaults");
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"https://api.pushed.ru/v2/mobile-push/confirm-client-interaction?clientInteraction=%ld", (long)interaction];
    NSLog(@"[Extension Interaction] %@: messageId=%@, clientToken=%@..., url=%@", interactionName, messageId, [clientToken substringToIndex:MIN(10, clientToken.length)], urlString);
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"[Extension Interaction] ERROR: Invalid URL: %@", urlString);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // Create Basic Auth exactly like in PushedIosLib: clientToken:messageId
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", clientToken, messageId];
    NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    NSString *basicAuth = [NSString stringWithFormat:@"Basic %@", [credentialsData base64EncodedStringWithOptions:0]];
    NSLog(@"[Extension Interaction] %@: Authorization header created", interactionName);
    [request addValue:basicAuth forHTTPHeaderField:@"Authorization"];
    
    NSDictionary *body = @{
        @"clientToken": clientToken,
        @"messageId": messageId
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[Extension Interaction] ERROR: JSON Serialization Error: %@", jsonError.localizedDescription);
        return;
    }
    
    request.HTTPBody = jsonData;
    NSLog(@"[Extension Interaction] %@: Request body created successfully", interactionName);
    
    NSLog(@"[Extension Interaction] %@: Sending HTTP request...", interactionName);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[Extension Interaction] %@: Request error: %@", interactionName, error.localizedDescription);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (!httpResponse) {
            NSLog(@"[Extension Interaction] %@: ERROR: No HTTPURLResponse", interactionName);
            return;
        }
        
        NSInteger status = httpResponse.statusCode;
        NSString *responseBody = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<no body>";
        
        if (status >= 200 && status < 300) {
            NSLog(@"[Extension Interaction] %@: SUCCESS - Status: %ld, Body: %@", interactionName, (long)status, responseBody);
        } else {
            NSLog(@"[Extension Interaction] %@: ERROR - Status: %ld, Body: %@", interactionName, (long)status, responseBody);
        }
    }];
    
    [task resume];
    NSLog(@"[Extension Interaction] %@: HTTP task started", interactionName);
    NSLog(@"[Extension Interaction] === %@ event processing completed ===", interactionName);
}

@end
