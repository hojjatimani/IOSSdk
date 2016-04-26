//
//  ViewController.m
//  SocketRocketTest
//
//  Created by Hojjat Imani on 10/9/1394 AP.
//  Copyright © 1394 Hojjat Imani. All rights reserved.
//

#import "ViewController.h"
#import <BRBefrest/BRBefrest.h>

#import <CommonCrypto/CommonDigest.h> // Need to import for CC_MD5 access
@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *refreshBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"viewDidLoad");
    NSNotificationCenter * notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter addObserver:self selector:@selector(BefrestNotifDidReceived:) name:BefrestPushReceivedNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(BefrestConnectionRefreshed) name:BefrestConnectionRefreshedNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(BefrestNotifDidReceived:) name:BefrestPushReceivedNotification object:nil];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Befrest Auth Generating
//
//-(NSString*) generateAuth: (NSString *)param{
//    //    NSString* temp = [self authProcess:(@"%@,%@", API_KEY, param)];
//    //    NSString* res = [self authProcess:(@"%@,%@", SHARED_KEY, temp)];
//    NSString * temp = [self authProcess:[NSString stringWithFormat:@"%@,%@", API_KEY, param]];
//    NSString * res = [self authProcess:[NSString stringWithFormat:@"%@,%@", SHARED_KEY, temp]];
//    return res;
//}
//
//-(NSString *) authProcess: (NSString *)param{
//    NSLog(@"0---%@", param);
//    NSString* md5 = [self md5:param];
//    NSLog(@"1---%@" , md5);
//    NSString* base64 = [self base64:md5];
//    NSString* result = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
//    result =[result stringByReplacingOccurrencesOfString:@"=" withString:@""];
//    result = [result stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
//    NSLog(@"2---%@", result);
//    return result;
//}
//
//-(NSString *) md5:(NSString *)s{
//    const char *cStr = [s UTF8String];
//    unsigned char result[CC_MD5_DIGEST_LENGTH];
//    CC_MD5( cStr, (int)strlen(cStr), result );
//    return [NSString stringWithFormat:
//            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
//            result[0], result[1], result[2], result[3],
//            result[4], result[5], result[6], result[7],
//            result[8], result[9], result[10], result[11],
//            result[12], result[13], result[14], result[15]
//            ];
//}
//
//-(NSString *) base64:(NSString *) s{
//    NSData *nsdata = [s dataUsingEncoding:NSUTF8StringEncoding];
//    return [nsdata base64EncodedStringWithOptions:0];
//}
//
//- (NSString *) encodeString:(NSString *) s {
//    NSLog(@"injaaaa---%@", s);
//    const char *cStr = [s UTF8String];
//    unsigned char result[CC_MD5_DIGEST_LENGTH];
//    CC_MD5(cStr, strlen(cStr), result);
//    NSMutableString *result1 = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
//    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
//        [result1 appendFormat:@"%02x", result[i]];
//    }
//    NSString * a = [NSString stringWithString:result1];
//    NSString* b = [a stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
//    b =[b stringByReplacingOccurrencesOfString:@"=" withString:@""];
//    b = [b stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
//    NSLog(@"%@", b);
//    return  b;
//}


#pragma mark - Befrest Events
- (void) BefrestNotifDidReceived: (NSNotification *) notif{
    NSArray * msgs = [[notif userInfo] objectForKey:BefrestMessages];
    for (BefrestMessage * msg in msgs) {
        [self.textView setText:[[self.textView text] stringByAppendingString:[NSString stringWithFormat:@"\n%@  %@", msg.timeStamp , msg.data]]];
    }
}

-(void) BefrestConnectionRefreshed{
    [self.refreshBtn setTitle:@"Refresh" forState:UIControlStateNormal];
}

#pragma mark - UI Actions

- (IBAction)refresh:(id)sender {
    BOOL willRefresh = [[BRBefrest sharedBefrest] refresh];
    if (willRefresh) {
        [self.refreshBtn setTitle:@"Refreshing ..." forState:UIControlStateNormal];
    }
}

@end
