//
//  BRBefrestMessage.m
//  BRBefrest
//
//  Created by Hojjat Imani on 2/7/1395 AP.
//  Copyright © 1395 Befrest. All rights reserved.
//

#import "BRBefrestMessage.h"

@implementation BRBefrestMessage


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