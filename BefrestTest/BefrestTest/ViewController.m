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


#pragma mark - Befrest Events
- (void) BefrestNotifDidReceived: (NSNotification *) notif{
    NSArray * msgs = [[notif userInfo] objectForKey:BefrestMessages];
    for (BRBefrestMessage * msg in msgs) {
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
