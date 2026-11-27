#import "LGNetworkContext.h"
#import "LGIdentity.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <arpa/inet.h>
@implementation LGNetworkContext
+ (instancetype)current{
 LGNetwork n;if(lg_network(&n))return nil;LGNetworkContext *context=[self new];context.network=n;
 NSDictionary *info=CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)@(n.interface)));
 NSString *ssid=[info[(__bridge id)kCNNetworkInfoKeySSID] isKindOfClass:NSString.class]?info[(__bridge id)kCNNetworkInfoKeySSID]:@"";
 NSString *bssid=[info[(__bridge id)kCNNetworkInfoKeyBSSID] isKindOfClass:NSString.class]?info[(__bridge id)kCNNetworkInfoKeyBSSID]:@"";char normalized[18];
 if(!lg_normalize_mac(bssid.UTF8String,normalized)){bssid=@"";if([ssid isEqual:@"Wi-Fi"]||[ssid isEqual:@"WLAN"])ssid=@"";}else bssid=@(normalized);
 context.ssid=ssid;context.bssid=bssid;context.title=ssid.length?ssid:@"Local Wi-Fi network";
 struct in_addr address={htonl(n.address&n.netmask)};char subnet[16];inet_ntop(AF_INET,&address,subnet,sizeof(subnet));
 context.networkKey=[NSString stringWithFormat:@"%s|%s|%s|%@|%@",subnet,n.mask,n.gateway,ssid,bssid];
 context.fingerprint=[context.networkKey stringByAppendingFormat:@"|%s|%s",n.ip,n.interface];return context;
}
@end
