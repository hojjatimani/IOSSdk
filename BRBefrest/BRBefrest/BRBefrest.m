//
//  Befrest.m
//  SocketRocketTest
//
//  Created by Hojjat Imani on 11/25/1394 AP.
//  Copyright © 1394 Hojjat Imani. All rights reserved.
//

#import "BRBefrest.h"
#import "BRReachability.h"
#import "BRWebSocket.h"
#import <UIKit/UIApplication.h>
#include <math.h>

#define BEFREST_DEBUG true
#if BEFREST_DEBUG
#define BefLog(...) NSLog(__VA_ARGS__)
#else
#define BefLog(...)
#endif

#define BEFREST_API_VERSION 1

#define CH_ID_KEY @"Befrest.Keys.ChIdKey"
#define U_ID_KEY @"Befrest.Keys.UIdKey"
#define AUTH_KEY @"Befrest.Keys.AuthKey"
#define TOPICS_KEY @"Befrest.Keys.TopicsKey"

#define PING_TIMEOUT 5.0
#define BATCH_TIMEOUT 1.0

typedef enum{
    PONG, DATA, BATCH, TOPIC, GROUP
}PushMsgType;


@interface BRBefrest () <SRWebSocketDelegate>

@property (readwrite, setter=internalSetChId:) NSString *chId;
@property (readwrite, setter=internalSetUId:) NSNumber *uId;
@property (readwrite, setter=internalSetAuth:) NSString *auth;

//initialization
-(id) initWithPreSetData;
-(id) commonInitialazation;
-(void) initEventNotifReceivers;
-(void) stopEventReceivers;

//internal connectiong
-(void)openConnectionIfNeededAndPossible;
-(void) openConnection;
-(void)cleanCloseConnection;

//pinging
-(void) startPinging;
-(void) setNextPingToSendInFuture;
-(NSTimeInterval) getPingInterval;
-(void) sendPing;
-(void) pongDidReceived:(NSString *) payload;
-(BOOL) isValidPong:(NSString *) payload;
-(void) restart;
-(void) stopPinging;

//retrying
-(void) scheduleRetry;
-(void) cancelFutureRetry;
-(void) retry;
-(NSTimeInterval) getRetryInterval;

//batch
-(void) finishBatch;

//application state transitiona
-(void) applicationWillResignActive: (NSNotification *) notif;
-(void) applicationDidBecomeActive: (NSNotification *) notif;

//notification sending
-(void) notifyBefrestRefreshedIfNeeded;
-(void) sendUnauthorizedNotification;
-(void) sendPushReceivedNotifications;
-(void) sendNofificationWithName: (NSString *) name andUserInfo: (NSDictionary *) userInfo;

//network reachability
-(void) reachabilityChanged:(NSNotification *) notif;

//message processing
-(void) sendMessageToClient: (NSDictionary *)msg;
-(void) addToMessages:(NSDictionary *)msg;
-(NSArray *) getMessages;

//utils
-(BOOL) isAlphaNumeric:(NSString *)s;
-(void) saveCredentials;
-(NSDictionary*) getParsedPushDataFrom:(NSString *) rawMessage;
-(NSString *) decodeBase64:(NSString *) base64String;
@end

@implementation BRBefrest{
    BRWebSocket * websocket;
    NSString *topics;
    BRReachability * reachability;
    NSMutableArray *messages;
    
    //states
    BOOL isInBatchMode;
    BOOL refreshInProgress;
    BOOL state_stopped;
    BOOL connectionCredentialsHasChangedSinceLastStart;
    
    //pinging
    NSTimer *pingTimer;
    NSTimer *restartTimer;
    NSString *pingDataPrefix;
    int currentPingId;
    int minPingInterval;
    int maxPingInterval;
    int pingStepsToMax;
    int currentPingStep;
    
    //retrying
    NSTimer *retryTimer;
    int minRetryInterval;
    int maxRetryInterval;
    int retryStepsToMax;
    int currentRetryStep;
}

#pragma mark - Initialization

+(id)sharedBefrest{
    static BRBefrest *sharedBefrest = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedBefrest = [[[self alloc] initWithPreSetData] commonInitialazation];
    });
    return sharedBefrest;
}

-(id)initWithPreSetData{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.chId = [defaults objectForKey:CH_ID_KEY];
    self.uId = [defaults objectForKey:U_ID_KEY];
    self.auth = [defaults objectForKey:AUTH_KEY];
    topics = [defaults objectForKey:TOPICS_KEY];
    return self;
}

-(id)commonInitialazation{
    //states
    state_stopped = true;
    
    //pinging
    minPingInterval = 10;
    maxPingInterval = 5 * 60;
    pingStepsToMax = 5;
    currentPingStep = 0;
    pingDataPrefix = [NSString stringWithFormat:@"%d", arc4random_uniform(9999)];
    currentPingId = 0;
    
    //retrying
    minRetryInterval = 1;
    maxRetryInterval = 2 * 60;
    retryStepsToMax = 5;
    currentRetryStep = 0;
    return self;
}

-(void) initEventNotifReceivers{
    reachability = [BRReachability reachabilityWithHostName:@"gw.bef.rest"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [reachability startNotifier];
}

-(void) stopEventReceivers{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [reachability stopNotifier];
    reachability = nil;
}

#pragma mark - credential setters

-(void)initWithUId:(long)uId andAuthToken:(NSString *)auth andChId:(NSString *)chId{
    BefLog(@"initWithConnetionParameters");
    [self setUId:[NSNumber numberWithLong:uId]];
    [self setAuth:auth];
    [self setChId:chId];
}

-(void) setChId:(NSString *)chId{
    [self internalSetChId:chId];
    [self saveCredentials];
}

-(void) setUId:(NSNumber *)uId{
    [self internalSetUId:uId];
    [self saveCredentials];
}

-(void) setAuth:(NSString *)auth{
    [self internalSetAuth:auth];
    [self saveCredentials];
}

-(BRBefrest*)addTopic:(NSString *)topicName{
    if(![self isAlphaNumeric:topicName])
        @throw [NSException exceptionWithName:@"Illegal Topic Name" reason:@"Topic Name must be an alphanumeric string." userInfo:nil];
    for (NSString* s in [topics componentsSeparatedByString:@"-"]) {
        if([topicName isEqualToString:s])
            return self;
    }
    if([topics length] > 0)
        topics = [topics stringByAppendingString:@"-"];
    topics = [topics stringByAppendingString:topicName];
    [self saveCredentials];
    return self;
}

-(BRBefrest*)removeTopic:(NSString *)topicName{
    NSArray<NSString*> * splitted = [topics componentsSeparatedByString:@"-"];
    BOOL found = false;
    NSString * resTopics = @"";
    for (NSString* s in splitted) {
        if([s isEqualToString:topicName])
            found = true;
        else
            resTopics = [resTopics stringByAppendingString:[NSString stringWithFormat:@"%@-", s]];
    }
    if(!found)
        @throw [NSException exceptionWithName:@"Topic Not Found" reason:@"No such topic was added before to be removed." userInfo:nil];
    if([resTopics length] > 0)
        resTopics = [resTopics substringToIndex:[resTopics length] -1];
    [self saveCredentials];
    return self;
}
-(NSArray *)currentTopics{
    return [topics componentsSeparatedByString:@"-"];
}

#pragma mark - API
-(void)start{
    dispatch_async(dispatch_get_main_queue(), ^{
        BefLog(@"start");
        if(state_stopped)
            [self initEventNotifReceivers];
        state_stopped = false;
        if (websocket == nil){
            if(connectionCredentialsHasChangedSinceLastStart){
                connectionCredentialsHasChangedSinceLastStart = false;
                [self cleanCloseConnection];
                [self openConnectionIfNeededAndPossible];
            }else{
                NSLog(@"starting...");
                [self openConnectionIfNeededAndPossible];
            }
        }else{
            BefLog(@"already connected! will call refresh.");
            [self refresh];
        }
    });
}

-(void)stop{
    dispatch_async(dispatch_get_main_queue(), ^{
        BefLog(@"stop");
        state_stopped = true;
        [self stopEventReceivers];
        [self cleanCloseConnection];
    });
}

-(BOOL)refresh{
    __block BOOL result;
    //make sure this runs on the main thread
    if (![NSThread isMainThread]){
        dispatch_sync(dispatch_get_main_queue(), ^{
            result = [self refresh];
        });
    }else{
        if (state_stopped || ![reachability isReachable] || refreshInProgress || (websocket != nil && [websocket readyState] == SR_CONNECTING))
            result = false;
        else{
            refreshInProgress = true;
            if (websocket == nil) {
                [self openConnectionIfNeededAndPossible];
            }else{
                [self stopPinging];
                [self sendPing];
            }
            result = true;
        }
    }
    return result;
}

#pragma mark - internal connecting

-(void)openConnectionIfNeededAndPossible{
    BefLog(@"openConnectionIfNeededAndPossible");
    if (websocket != nil) {
        BefLog(@"a connection already exists!");
        return;
    }
    if(![reachability isReachable]){
        BefLog(@"Cant open connection. Network unreachable!");
        return;
    }
    
    //cancel any pending retry if is set
    [self cancelFutureRetry];
    [self openConnection];
}

-(void) openConnection{
    BefLog(@"openConnection");
    NSString* url = [NSString stringWithFormat:@"wss://gw.bef.rest/xapi/%d/subscribe/%d/%@/%d", BEFREST_API_VERSION, [self.uId intValue], self.chId, BEFREST_SDK_VERSION];
    //    NSLog(@"%@", url);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSMutableURLRequest *mRequest = [request mutableCopy];
    [mRequest addValue:self.auth forHTTPHeaderField:@"X-BF-AUTH"];
    [mRequest addValue:topics forHTTPHeaderField:@"X-BF-TOPICS"];
    request = [mRequest copy];
    websocket = [[BRWebSocket alloc] initWithURLRequest:request];
    websocket.delegate = self;
    [websocket open];
}

-(void)cleanCloseConnection{
    if (websocket == nil) {
        BefLog(@"connection already closed!");
        return;
    }
    [self stopPinging];
    websocket.delegate = nil;
    [websocket close];
    websocket = nil;
}

#pragma mark - Websocket Delegate Methods
-(void)webSocketDidOpen:(BRWebSocket *)webSocket{
    [self sendNofificationWithName:BefrestConnectedNotification andUserInfo:nil];
    [self notifyBefrestRefreshedIfNeeded];
    [self startPinging];
}

-(void)webSocket:(BRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClear{
    BefLog(@"didCloseWithCode:%d", (int)code);
    [self cleanCloseConnection];
    if (![reachability isReachable])
        [self scheduleRetry];
}

-(void)webSocket:(BRWebSocket *)webSocket didFailWithError:(NSError *)error{
    BefLog(@"didFailWithError:%@", error);
    if ([error code] == 401) {
        BefLog(@"UnAuthorized!");
        [self stop];
        [self sendUnauthorizedNotification];
    }else{
        [self cleanCloseConnection];
        if (![reachability isReachable])
            [self scheduleRetry];
        
    }
}

-(void)webSocket:(BRWebSocket *)webSocket didReceiveMessage:(id)message{
    BefLog(@"Push Received. raw: %@" , message);
    NSDictionary* pushMsg = [self getParsedPushDataFrom:message];
    NSNumber *msgType = [pushMsg objectForKey:@"t"];
    BefLog(@"msgType::: %d", [msgType intValue]);
    switch ([msgType intValue]) {
        case PONG:
            //depricated
            break;
        case BATCH:
            isInBatchMode = YES;
            [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(finishBatch) userInfo:nil repeats:NO];
            break;
        case DATA:
        case GROUP:
        case TOPIC:
        {
            NSString *msgId = [pushMsg objectForKey:@"messageId"];
            if (msgId != nil) {
                //todo ack message
                //todo if message is new
                [self sendMessageToClient:pushMsg];
            }else
                [self sendMessageToClient:pushMsg];
            break;
        }
        default:
            BefLog(@"unKnown message type!");
            break;
    }
}

-(void)webSocket:(BRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload{
    [self pongDidReceived:[[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding]];
}

#pragma mark - Pinging

-(void) startPinging{
    currentPingStep = 0;
    [self setNextPingToSendInFuture];
}

-(void) setNextPingToSendInFuture{
    NSTimeInterval interval = [self getPingInterval];
    [pingTimer invalidate];
    currentPingId = (currentPingId + 1) %6;
    pingTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(sendPing) userInfo:nil repeats:NO];
    BefLog(@"setNextPingToSendAfter  %fsec", interval);
}

-(NSTimeInterval) getPingInterval{
    float factor = ((float)currentPingStep/pingStepsToMax);
    return  minPingInterval + pow(((factor > 1 ? 1 : factor) * pow(maxPingInterval - minPingInterval, 0.5)) , 2);
}

-(void) sendPing{
    BefLog(@"sendPing");
    if(websocket){
        NSString * pingPayload = [NSString stringWithFormat:@"%@%d", pingDataPrefix , currentPingId];
        [websocket sendPing:[pingPayload dataUsingEncoding:NSUTF8StringEncoding]];
        restartTimer = [NSTimer scheduledTimerWithTimeInterval:PING_TIMEOUT target:self selector:@selector(restart) userInfo:nil repeats:NO];
        BefLog(@"Ping Sent with Data: %@" , pingPayload);
    }
}

-(void) pongDidReceived:(NSString *) payload{
    bool isValid = [self isValidPong:payload];
    BefLog(@"pong Received With Data: %@ (%@)", payload, isValid ? @"valid" : @"invalid!");
    if (!isValid)
        return;
    [restartTimer invalidate];
    currentPingStep ++;
    [self notifyBefrestRefreshedIfNeeded];
    [self setNextPingToSendInFuture];
}

-(BOOL) isValidPong:(NSString *) payload{
    NSString * desired = [NSString stringWithFormat:@"%@%d", pingDataPrefix , currentPingId];
    return [payload isEqualToString:desired];
}

-(void) restart{
    [self cleanCloseConnection];
    [self openConnectionIfNeededAndPossible];
}

-(void) stopPinging{
    [pingTimer invalidate];
    [restartTimer invalidate];
}

#pragma mark - Retrying

-(void) scheduleRetry{
    NSTimeInterval interval = [self getRetryInterval];
    retryTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(retry) userInfo:nil repeats:NO];
    BefLog(@"scheduleRetry for %fsec later", interval);
}

-(void) cancelFutureRetry{
    [retryTimer invalidate];
}

-(void) retry{
    [self openConnectionIfNeededAndPossible];
}

-(NSTimeInterval) getRetryInterval{
    float factor = ((float)currentRetryStep/retryStepsToMax);
    return  minRetryInterval + pow(((factor > 1 ? 1 : factor) * pow(maxRetryInterval - minRetryInterval, 0.5)) , 2);
}

#pragma mark - Batch

-(void) finishBatch{
    isInBatchMode = NO;
    [self sendPushReceivedNotifications];
}

#pragma mark - Application State Changes

-(void) applicationWillResignActive: (NSNotification *) notif{
    BefLog(@"applicationWillResignActive");
    [self cleanCloseConnection];
}

-(void) applicationDidBecomeActive: (NSNotification *) notif{
    BefLog(@"applicationDidBecomeActive");
    [self openConnectionIfNeededAndPossible];
}

#pragma mark - Notification Sending

-(void) notifyBefrestRefreshedIfNeeded{
    if (refreshInProgress) {
        refreshInProgress = false;
        [self sendNofificationWithName:BefrestConnectionRefreshedNotification andUserInfo:nil];
    }
}

-(void) sendUnauthorizedNotification{
    [self sendNofificationWithName:BefrestAuthenticationFaildNotification andUserInfo:nil];
}

-(void) sendPushReceivedNotifications{
    NSDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[messages copy] forKey:BefrestMessages];
    messages = nil;
    [self sendNofificationWithName:BefrestPushReceivedNotification andUserInfo:userInfo];
}

-(void) sendNofificationWithName: (NSString *) name andUserInfo: (NSDictionary *) userInfo{
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
}

#pragma mark - reachability

-(void) reachabilityChanged:(NSNotification *) notif{
    if([reachability isReachable]){
        BefLog(@"Nework Reachable");
        if (!state_stopped) {
            [self openConnectionIfNeededAndPossible];
        }
    }else{
        BefLog(@"Network UnReachable");
        [self cleanCloseConnection];
    }
}

#pragma mark - Message Processing

-(NSDictionary*) getParsedPushDataFrom:(NSString *) rawMessage{
    NSData *jsonData = [rawMessage dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&e];
    if(json != nil)
        json = [json mutableCopy];
    else
        json = [NSMutableDictionary dictionary];
    if ([json objectForKey:@"t"] == nil || [json objectForKey:@"ts"] == nil || [json objectForKey:@"m"] == nil) {
        //message version 0
        BefLog(@"version0");
        BefLog(@"Data is %d--%@", DATA, [NSNumber numberWithInt:DATA]);
        [json setValue:[NSNumber numberWithInt:DATA] forKey:@"t"];
        BefLog(@"setId%d" , [[json objectForKey:@"t"] intValue]);
        [json setValue:rawMessage forKey:@"m"];
        [json setValue:@"unKnown" forKey:@"ts"];
    }else{
        //message version 1 or 2
        BefLog(@"version1or2");
        [json setValue:[self decodeBase64:[json objectForKey:@"m"]] forKey:@"m"];
    }
    return json;
}

-(void) sendMessageToClient: (NSDictionary *)msg{
    [self addToMessages:msg];
    if (!isInBatchMode)
        [self sendPushReceivedNotifications];
}

-(void) addToMessages:(NSDictionary *)msg{
    if(!messages)
        messages = [NSMutableArray array];
    [messages addObject:[BefrestMessage createWithData:[msg objectForKey:@"m"] andTimeStamp:[msg objectForKey:@"ts"]]];
}

-(NSArray *) getMessages{
    NSArray * result = [messages copy];
    messages = nil;
    
    return result;
}

#pragma mark - Utils

-(BOOL) isAlphaNumeric: (NSString *) s{
    NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
    return [[s stringByTrimmingCharactersInSet:alphaSet] isEqualToString:@""];
}

-(void) saveCredentials{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.chId forKey:CH_ID_KEY];
    [defaults setObject:self.uId forKey:U_ID_KEY];
    [defaults setObject:self.auth forKey:AUTH_KEY];
    [defaults setObject:topics forKey:TOPICS_KEY];
    [defaults synchronize];
    connectionCredentialsHasChangedSinceLastStart = true;
}

-(NSString *) decodeBase64:(NSString *) base64String{
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

@end

#pragma mark - Inner Classes

@implementation BefrestMessage

+(id) createWithData:(NSString *)data andTimeStamp: (NSString *) ts{
    return [[self alloc] initwithData:data andTimeStamp:ts];
}

-(void) print{
    NSLog(@"BefrestPush:: data:%@  ,  timestamp:%@", self.data, self.timeStamp);
}

-(id) initwithData:(NSString *)data andTimeStamp: (NSString *) ts{
    self.data = data;
    self.timeStamp = ts;
    return self;
}

@end