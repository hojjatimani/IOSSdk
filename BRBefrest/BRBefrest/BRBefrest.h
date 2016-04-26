//
//  Befrest.h
//  SocketRocketTest
//
//  Created by Hojjat Imani on 11/25/1394 AP.
//  Copyright © 1394 Hojjat Imani. All rights reserved.
//

#import <Foundation/Foundation.h>

#define BEFREST_SDK_VERSION 1

#define BefrestPushReceivedNotification @"BefrestPushReceivedNotification"
#define BefrestConnectedNotification @"BefrestConnectedNotification"
#define BefrestAuthenticationFaildNotification @"BefrestAuthenticationFaildNotification"
#define BefrestConnectionRefreshedNotification @"BefrestConnectionRefreshed"

#define BefrestMessages @"BefrestMessages"

@interface  BRBefrest : NSObject

@property (readonly) NSString *chId;
@property (readonly) NSNumber *uId;
@property (readonly) NSString *auth;

+(id) sharedBefrest;

-(void) initWithUId:(long) uid andAuthToken: (NSString *) auth andChId: (NSString *) chId;
-(void) setUId:(NSNumber *)uId;
-(void) setChId:(NSString *)chId;
-(void) setAuth:(NSString *)auth;
-(void) start;
-(void) stop;
-(BOOL) refresh;
-(BRBefrest*) addTopic: (NSString*) topicName;
-(BRBefrest*) removeTopic: (NSString*) topicName;
-(NSArray*) currentTopics;

@end

@interface BefrestMessage : NSObject

@property NSString* data;
@property NSString* timeStamp;

+(id) createWithData:(NSString *)data andTimeStamp: (NSString *) ts;

-(void) print;

@end