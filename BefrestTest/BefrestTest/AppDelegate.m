//
//  AppDelegate.m
//  SocketRocketTest
//
//  Created by Hojjat Imani on 10/9/1394 AP.
//  Copyright © 1394 Hojjat Imani. All rights reserved.
//

#import "AppDelegate.h"
#import <BRBefrest/BRBefrest.h>


#define UID 10050
#define SHARED_KEY @"22222222222222222222222222298222222"
#define API_KEY @"1BB64EC5F8416A8F857FF5B019905446"

#define CHID @"1"
#define AUTH @"bwgFvd8lJ-X0qnQAlSguRw"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    NSLog(@"STATUS::: didFinishLaunchingWithOptions");
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(befrestNotifDidReceived:) name:BefrestPushReceivedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(befrestUnAuthorizeProblem:) name:BefrestAuthenticationFaildNotification object:nil];
    
    BRBefrest * befrest = [BRBefrest sharedBefrest];
    [befrest initWithUId:UID andAuthToken:[AUTH stringByAppendingString:@"olagh"] andChId:CHID];
    [befrest start];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    NSLog(@"STATUS::: applicationWillResignActive");
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
        NSLog(@"STATUS::: applicationDidEnterBackground");
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
        NSLog(@"STATUS::: applicationWillEnterForeground");
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
        NSLog(@"STATUS::: applicationDidBecomeActive");
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
        NSLog(@"STATUS::: applicationWillTerminate");
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)befrestNotifDidReceived: (NSNotification *) notif{
    NSArray * msgs = [[notif userInfo] objectForKey:BefrestMessages];
    NSLog(@"#msgs:%lu", (unsigned long)[msgs count]);
//    for (BefrestMessage* msg in msgs) {
//    }
}

- (void)befrestUnAuthorizeProblem: (NSNotification *) notif{
    NSLog(@"authentication faild!");
    [[BRBefrest sharedBefrest] setAuth:AUTH];
    [(BRBefrest *)[BRBefrest sharedBefrest ] start];
}

@end
