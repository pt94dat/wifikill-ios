#import "LGBonjourInventory.h"
#import <arpa/inet.h>
@interface LGBonjourInventory ()
@property(nonatomic,strong) NSMutableArray *browsers,*services;
@property(nonatomic,strong) NSMutableDictionary *evidence;
@property(nonatomic,copy) void(^completion)(NSDictionary*);
@property(nonatomic) BOOL finished;
@property(nonatomic,strong) NSMutableDictionary *stats;
@property(nonatomic,strong) NSMutableSet *resolved;
@end
@implementation LGBonjourInventory
- (NSDictionary*)diagnostics{return self.stats.copy?:@{};}
- (void)cancel{self.finished=YES;self.completion=nil;for(NSNetServiceBrowser *b in self.browsers){b.delegate=nil;[b stop];}for(NSNetService *s in self.services){s.delegate=nil;[s stop];}}
- (void)bump:(NSString*)key{self.stats[key]=@([self.stats[key] unsignedIntegerValue]+1);}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didNotSearch:(NSDictionary*)error{(void)browser;if(self.finished)return;[self bump:@"browserFailures"];self.stats[@"lastBrowserCode"]=error[NSNetServicesErrorCode]?:@0;}
- (void)netService:(NSNetService*)service didNotResolve:(NSDictionary*)error{(void)service;if(self.finished)return;[self bump:@"resolveFailures"];self.stats[@"lastResolveCode"]=error[NSNetServicesErrorCode]?:@0;}
- (void)collect:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion {[self collectWithWindowMS:1500 completion:completion];}
- (void)collectWithWindowMS:(NSUInteger)window completion:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion {
 window=MAX(1000,MIN(4000,window));
 NSAssert(NSThread.isMainThread,@"Bonjour collection requires the main run loop");self.completion=completion;self.browsers=[NSMutableArray new];self.services=[NSMutableArray new];self.evidence=[NSMutableDictionary new];self.finished=NO;self.stats=[@{@"windowMS":@(window),@"browsersStarted":@6,@"found":@0,@"resolved":@0,@"browserFailures":@0,@"resolveFailures":@0,@"removed":@0} mutableCopy];self.resolved=[NSMutableSet new];
 for(NSString *type in @[@"_workstation._tcp.",@"_device-info._tcp.",@"_airplay._tcp.",@"_ipp._tcp.",@"_googlecast._tcp.",@"_companion-link._tcp."]){NSNetServiceBrowser *browser=[NSNetServiceBrowser new];browser.delegate=self;[self.browsers addObject:browser];[browser searchForServicesOfType:type inDomain:@"local."];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,window*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.finished)return;self.stats[@"deadlineReached"]=@YES;self.stats[@"unresolvedAtDeadline"]=@(self.services.count-self.resolved.count);self.finished=YES;for(NSNetServiceBrowser *b in self.browsers)[b stop];for(NSNetService *s in self.services)[s stop];void(^done)(NSDictionary*)=self.completion;self.completion=nil;if(done)done(self.evidence.copy);});
}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindService:(NSNetService*)service moreComing:(BOOL)more {(void)browser;(void)more;if(self.finished||self.services.count>=64)return;if([self.services containsObject:service])return;[self bump:@"found"];[self.services addObject:service];service.delegate=self;[service resolveWithTimeout:1];}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didRemoveService:(NSNetService*)service moreComing:(BOOL)more{(void)browser;(void)more;[self bump:@"removed"];for(NSString *key in self.evidence.allKeys)if([self.evidence[key][@"name"] isEqual:service.name]&&[self.evidence[key][@"service"] isEqual:service.type])[self.evidence removeObjectForKey:key];}
- (void)netServiceDidResolveAddress:(NSNetService*)service {
 if(self.finished)return;if(![self.resolved containsObject:service]){[self.resolved addObject:service];[self bump:@"resolved"];}NSString *name=service.name.length?service.name:service.hostName;if(!name.length||name.length>128)return;
 for(NSData *data in service.addresses){if(data.length<sizeof(struct sockaddr_in))continue;const struct sockaddr *sa=data.bytes;if(sa->sa_family!=AF_INET)continue;const struct sockaddr_in *addr=data.bytes;char ip[16];inet_ntop(AF_INET,&addr->sin_addr,ip,sizeof(ip));
  NSString *hint=[service.type containsString:@"_ipp."]?@"Printer service advertised":([service.type containsString:@"_airplay."]?@"AirPlay service advertised":([service.type containsString:@"_googlecast."]?@"Cast service advertised":@"Device type unknown"));
  NSDictionary *previous=self.evidence[@(ip)];if(previous&&[hint isEqual:@"Device type unknown"])continue;self.evidence[@(ip)]=@{@"name":name,@"host":service.hostName?:@"",@"service":service.type?:@"",@"typeHint":hint};
 }
}
@end
