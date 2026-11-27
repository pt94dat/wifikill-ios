#import <Foundation/Foundation.h>
#import "LGNetwork.h"
@interface LGNetworkContext:NSObject
@property(nonatomic) LGNetwork network;
@property(nonatomic,copy) NSString *networkKey,*fingerprint,*ssid,*bssid,*title;
+ (instancetype)current;
@end
