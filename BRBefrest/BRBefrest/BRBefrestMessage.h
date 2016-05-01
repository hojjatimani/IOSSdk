//
//  BRBefrestMessage.h
//  BRBefrest
//
//  Created by Hojjat Imani on 2/7/1395 AP.
//  Copyright © 1395 Befrest. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRBefrestMessage : NSObject

@property NSString* data;
@property NSString* timeStamp;

+(id) createWithData:(NSString *)data andTimeStamp: (NSString *) ts;

-(void) print;

@end