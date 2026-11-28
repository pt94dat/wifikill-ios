#import "LGBonjourInventory.h"
#import <arpa/inet.h>
#import <dns_sd.h>
#import "LGIdentity.h"
#import "LGServiceEvidence.h"
@interface LGBonjourInventory ()
@property(nonatomic,strong) NSMutableArray *browsers,*services;
@property(nonatomic,strong) NSMutableDictionary *evidence;
@property(nonatomic,copy) void(^completion)(NSDictionary*);
@property(nonatomic) BOOL finished;
@property(nonatomic) NSUInteger epoch;
@property(nonatomic,strong) NSMutableDictionary *stats;
@property(nonatomic,strong) NSMutableSet *resolved,*types;
@property(nonatomic,assign) DNSServiceRef enumeration;
- (void)bump:(NSString*)key;
- (void)browse:(NSString*)type;
@end
@implementation LGBonjourInventory
static void type_reply(DNSServiceRef ref,DNSServiceFlags flags,uint32_t interface,DNSServiceErrorType error,const char *fullname,uint16_t rrtype,uint16_t rrclass,uint16_t length,const void *data,uint32_t ttl,void *context){
 (void)ref;(void)interface;(void)fullname;(void)rrclass;(void)ttl;LGBonjourInventory *self=(__bridge LGBonjourInventory*)context;if(self.finished)return;if(error){self.stats[@"typeEnumerationCode"]=@(error);return;}if(!(flags&kDNSServiceFlagsAdd)||rrtype!=kDNSServiceType_PTR||!data)return;
 char decoded[256];if(!lg_ptr_name(data,length,decoded,sizeof(decoded)))return;NSString *type=[LGServiceEvidence serviceType:@(decoded)];if(type){[self bump:@"enumeratedTypes"];[self browse:type];}
}
- (void)browse:(NSString*)type{if(self.types.count>=16||[self.types containsObject:type])return;[self.types addObject:type];NSNetServiceBrowser *browser=[NSNetServiceBrowser new];browser.delegate=self;[self.browsers addObject:browser];[self bump:@"browsersStarted"];[browser searchForServicesOfType:type inDomain:@"local."];}
- (void)stopAll{for(NSNetServiceBrowser *b in self.browsers){b.delegate=nil;[b stop];}for(NSNetService *s in self.services){s.delegate=nil;[s stop];}if(self.enumeration){DNSServiceRefDeallocate(self.enumeration);self.enumeration=NULL;}}

- (NSDictionary*)diagnostics{return self.stats.copy?:@{};}
- (void)cancel{self.epoch++;self.finished=YES;self.completion=nil;void(^cancelled)(void)=self.onCancel;self.onCancel=nil;[self stopAll];if(cancelled)cancelled();}
- (void)bump:(NSString*)key{self.stats[key]=@([self.stats[key] unsignedIntegerValue]+1);}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didNotSearch:(NSDictionary*)error{(void)browser;if(self.finished)return;[self bump:@"browserFailures"];self.stats[@"lastBrowserCode"]=error[NSNetServicesErrorCode]?:@0;}
- (void)netService:(NSNetService*)service didNotResolve:(NSDictionary*)error{(void)service;if(self.finished)return;[self bump:@"resolveFailures"];self.stats[@"lastResolveCode"]=error[NSNetServicesErrorCode]?:@0;}
- (void)collect:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion {[self collectWithWindowMS:1500 completion:completion];}
- (void)collectWithWindowMS:(NSUInteger)window completion:(void(^)(NSDictionary<NSString*,NSDictionary*>*))completion {
 [self cancel];NSUInteger epoch=self.epoch;window=MAX(1000,MIN(5000,window));
 NSAssert(NSThread.isMainThread,@"Bonjour collection requires the main run loop");self.completion=completion;self.browsers=[NSMutableArray new];self.services=[NSMutableArray new];self.evidence=[NSMutableDictionary new];self.finished=NO;self.stats=[@{@"windowMS":@(window),@"browsersStarted":@0,@"enumeratedTypes":@0,@"found":@0,@"resolved":@0,@"browserFailures":@0,@"resolveFailures":@0,@"removed":@0} mutableCopy];self.resolved=[NSMutableSet new];self.types=[NSMutableSet new];
 for(NSString *type in @[@"_workstation._tcp.",@"_device-info._tcp.",@"_airplay._tcp.",@"_ipp._tcp.",@"_googlecast._tcp.",@"_companion-link._tcp."])[self browse:type];
 DNSServiceRef enumeration=NULL;int code=DNSServiceQueryRecord(&enumeration,0,0,"_services._dns-sd._udp.local.",kDNSServiceType_PTR,kDNSServiceClass_IN,type_reply,(__bridge void*)self);if(!code){code=DNSServiceSetDispatchQueue(enumeration,dispatch_get_main_queue());if(!code)self.enumeration=enumeration;else DNSServiceRefDeallocate(enumeration);}self.stats[@"typeEnumerationCode"]=@(code);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,window*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.finished||self.epoch!=epoch)return;self.stats[@"deadlineReached"]=@YES;self.stats[@"unresolvedAtDeadline"]=@(self.services.count-self.resolved.count);self.finished=YES;self.onCancel=nil;[self stopAll];void(^done)(NSDictionary*)=self.completion;self.completion=nil;if(done)done(self.evidence.copy);});
}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindService:(NSNetService*)service moreComing:(BOOL)more {(void)more;if(self.finished||(browser&&![self.browsers containsObject:browser])||self.services.count>=64)return;if([self.services containsObject:service])return;[self bump:@"found"];[self.services addObject:service];service.delegate=self;[service resolveWithTimeout:2];}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didRemoveService:(NSNetService*)service moreComing:(BOOL)more{(void)browser;(void)more;if(self.finished)return;[self bump:@"removed"];for(NSNetService *old in self.services.copy)if([old.name isEqual:service.name]&&[old.type isEqual:service.type]){old.delegate=nil;[old stop];[self.services removeObject:old];[self.resolved removeObject:old];}for(NSString *key in self.evidence.allKeys){NSDictionary *remaining=[LGServiceEvidence removeName:service.name type:service.type previous:self.evidence[key]];if(remaining)self.evidence[key]=remaining;else[self.evidence removeObjectForKey:key];}}
- (void)netServiceDidResolveAddress:(NSNetService*)service {
 if(self.finished||![self.services containsObject:service])return;if(![self.resolved containsObject:service]){[self.resolved addObject:service];[self bump:@"resolved"];}NSString *name=service.name.length?service.name:service.hostName;if(!name.length||name.length>128)return;
 for(NSData *data in service.addresses){if(data.length<sizeof(struct sockaddr_in))continue;const struct sockaddr *sa=data.bytes;if(sa->sa_family!=AF_INET)continue;const struct sockaddr_in *addr=data.bytes;char ip[16];inet_ntop(AF_INET,&addr->sin_addr,ip,sizeof(ip));
  NSString *hint=[service.type containsString:@"_ipp."]?@"Printer service advertised":([service.type containsString:@"_airplay."]?@"AirPlay service advertised":([service.type containsString:@"_googlecast."]?@"Cast service advertised":@"Device type unknown"));
  NSMutableDictionary *row=[@{@"name":name,@"host":service.hostName?:@"",@"service":service.type?:@"",@"typeHint":hint} mutableCopy];
  NSData *txt=service.TXTRecordData;if(txt.length&&txt.length<=4096){NSDictionary *fields=[NSNetService dictionaryFromTXTRecordData:txt];for(NSString *key in @[@"model",@"manufacturer"]){NSData *raw=fields[key];if(![raw isKindOfClass:NSData.class]||!raw.length||raw.length>128)continue;NSString *value=[[NSString alloc]initWithData:raw encoding:NSUTF8StringEncoding];if(value.length&&[value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound)row[key]=value;}}self.evidence[@(ip)]=[LGServiceEvidence mergeObservation:row previous:self.evidence[@(ip)]];
 }
}
@end
