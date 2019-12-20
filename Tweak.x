#import <Foundation/Foundation.h>
#import <UIKit/UIWindow+Private.h>
#include <net/if.h>
#include <sys/sysctl.h>

static int mib_wifi[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
static int mib_wwan[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
static const size_t buffer_size = 2048;
static char buffer[buffer_size];
static u_int64_t lastBytes = 0;

static NSString *formatSpeed(u_int64_t bytes) {
    @autoreleasepool {
        if (bytes < 1024) return [NSString stringWithFormat:@"%lluB/s", bytes];
        else if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1fK/s", (float)bytes / 1024];
        else if (bytes < 1024 * 1024 * 1024) return [NSString stringWithFormat:@"%.2fM/s", (float)bytes / (1024 * 1024)];
        else return [NSString stringWithFormat:@"%.3fG/s", (float)bytes / (1024 * 1024 * 1024)];
    }
}

static u_int64_t getTotalBytes() {
    @autoreleasepool {
        size_t len = buffer_size;
        u_int64_t totalBytes = 0;
        if (sysctl(mib_wwan, 6, buffer, &len, NULL, 0) == 0) {
            struct if_msghdr2 *ifm2 = (struct if_msghdr2 *)buffer;
            totalBytes += ifm2->ifm_data.ifi_ibytes + ifm2->ifm_data.ifi_obytes;
        }
        len = buffer_size;
        if (sysctl(mib_wifi, 6, buffer, &len, NULL, 0) == 0) {
            struct if_msghdr2 *ifm2 = (struct if_msghdr2 *)buffer;
            totalBytes += ifm2->ifm_data.ifi_ibytes + ifm2->ifm_data.ifi_obytes;
        }
        return totalBytes;
    }
}

@interface Nspeed : NSObject {
    UIWindow *springboardWindow;
    UILabel *label;
    UIView *backView;
    UIView *content;
}
@property(nonatomic, strong) UIWindow *springboardWindow;
@property(nonatomic, strong) UILabel *label;
@property(nonatomic, strong) UIView *backView;
@property(nonatomic, strong) UIView *content;
+ (id)sharedInstance;
- (void)update;
@end
@implementation Nspeed
@synthesize springboardWindow, label, backView, content;
__strong static id _sharedInstance;
+ (id)sharedInstance {
    if (!_sharedInstance) {
        _sharedInstance = [[self alloc] init];
        [NSTimer scheduledTimerWithTimeInterval:1 target:_sharedInstance selector:@selector(update) userInfo:nil repeats:YES];
    }
    return _sharedInstance;
}
- (id)init {
    mib_wifi[5] = if_nametoindex("en0");
    mib_wwan[5] = if_nametoindex("pdp_ip0");

    self = [super init];
    if (self != nil) {
        springboardWindow = [[UIWindow alloc] initWithFrame:CGRectMake([[UIScreen mainScreen] bounds].size.width - 77.25, 3, 40, 12)];
        springboardWindow.windowLevel = 9999;
        springboardWindow.alpha = 1;
        [springboardWindow _setSecure:YES];
        [springboardWindow setUserInteractionEnabled:NO];
        springboardWindow.layer.cornerRadius = 6;
        springboardWindow.layer.masksToBounds = YES;
        [springboardWindow setHidden:NO];

        backView = [UIView new];
        backView.frame = CGRectMake(0, 0, springboardWindow.frame.size.width, springboardWindow.frame.size.height);
        backView.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
        backView.layer.shouldRasterize = YES;
        backView.layer.rasterizationScale = backView.layer.contentsScale;
        [(UIView *)springboardWindow addSubview:backView];

        content = [UIView new];
        content.alpha = 0.9f;
        content.frame = CGRectMake(4, 0, springboardWindow.frame.size.width - 8, springboardWindow.frame.size.height);
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, content.frame.size.width, content.frame.size.height)];
        label.textColor = [UIColor whiteColor];
        label.adjustsFontSizeToFitWidth = YES;
        label.numberOfLines = 1;
        label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        label.textAlignment = NSTextAlignmentCenter;
        [content addSubview:label];
        [(UIView *)springboardWindow addSubview:content];
    }
    return self;
}
- (void)update {
    @autoreleasepool {
        if (!springboardWindow) return;
        u_int64_t nowBytes = getTotalBytes();
        u_int64_t bytes = nowBytes - lastBytes;
        lastBytes = nowBytes;
        if (bytes <= 0) {
            [springboardWindow setHidden:YES];
        } else {
            if (label) label.text = formatSpeed(bytes);
            [springboardWindow setHidden:NO];
        }
    }
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
    %orig;
    [[Nspeed sharedInstance] update];
}
%end
