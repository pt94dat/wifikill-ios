#import "LGBonjourInventory.h"
#import <arpa/inet.h>
@interface LGBonjourInventory ()
@property(nonatomic,strong) NSMutableArray *browsers,*services;
@property(nonatomic,strong) NSMutableDictionary *evidence;
@property(nonatomic,copy) void(^completion)(NSDictionary*);
@property(nonatomic) BOOL finished;
@end
@implementation LGBonjourInventory
- (void)collect:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion {
 NSAssert(NSThread.isMainThread,@"Bonjour collection requires the main run loop");self.completion=completion;self.browsers=[NSMutableArray new];self.services=[NSMutableArray new];self.evidence=[NSMutableDictionary new];self.finished=NO;
 for(NSString *type in @[@"_workstation._tcp.",@"_device-info._tcp.",@"_airplay._tcp.",@"_ipp._tcp.",@"_googlecast._tcp.",@"_companion-link._tcp."]){NSNetServiceBrowser *browser=[NSNetServiceBrowser new];browser.delegate=self;[self.browsers addObject:browser];[browser searchForServicesOfType:type inDomain:@"local."];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{self.finished=YES;for(NSNetServiceBrowser *b in self.browsers)[b stop];for(NSNetService *s in self.services)[s stop];void(^done)(NSDictionary*)=self.completion;self.completion=nil;if(done)done(self.evidence.copy);});
}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindService:(NSNetService*)service moreComing:(BOOL)more {(void)browser;(void)more;if(self.finished||self.services.count>=64)return;[self.services addObject:service];service.delegate=self;[service resolveWithTimeout:1];}
- (void)netServiceDidResolveAddress:(NSNetService*)service {
 if(self.finished)return;NSString *name=service.name.length?service.name:service.hostName;if(!name.length||name.length>128)return;
 for(NSData *data in service.addresses){if(data.length<sizeof(struct sockaddr_in))continue;const struct sockaddr *sa=data.bytes;if(sa->sa_family!=AF_INET)continue;const struct sockaddr_in *addr=data.bytes;char ip[16];inet_ntop(AF_INET,&addr->sin_addr,ip,sizeof(ip));
  NSString *hint=[service.type containsString:@"_ipp."]?@"Printer service advertised":([service.type containsString:@"_airplay."]?@"AirPlay service advertised":([service.type containsString:@"_googlecast."]?@"Cast service advertised":@"Device type unknown"));
  self.evidence[@(ip)]=@{@"name":name,@"host":service.hostName?:@"",@"service":service.type?:@"",@"typeHint":hint};
 }
}
@end
