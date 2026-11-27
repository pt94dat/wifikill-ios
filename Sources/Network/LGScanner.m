#import "LGScanner.h"
#import "LGIdentity.h"
#import "LGNetBIOS.h"
#import "LGBonjourInventory.h"
#import "Storage/LGStore.h"
#import <arpa/inet.h>
#import <net/if.h>
@implementation LGScanner
- (void)cancel{self.generation++;}
- (void)scan:(void(^)(NSArray<LGDevice*>*,NSString*))completion{
 [self cancel];NSUInteger generation=self.generation;LGNetworkContext *start=[LGNetworkContext current];self.context=start;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{
  unsigned base=0,hosts=0;
  if(!start||!lg_subnet_hosts(start.network.address,start.network.netmask,&base,&hosts)){dispatch_async(dispatch_get_main_queue(),^{if(self.generation==generation){self.metrics=@{};completion(@[],start?@"Unsupported subnet size; no partial count shown":@"No local Wi-Fi IPv4 connection");}});return;}
  NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=12;NSMutableDictionary<NSString*,LGDevice*> *found=[NSMutableDictionary new];
  for(unsigned h=1;h<=hosts;h++){
   if(self.generation!=generation)break;
   [queue addOperationWithBlock:^{@autoreleasepool{
    if(self.generation!=generation)return;struct in_addr address={htonl(base+h)};char ip[16];inet_ntop(AF_INET,&address,ip,16);BOOL local=base+h==start.network.address;double ms=0;int evidence=local?3:0;
    if(!local&&!lg_probe_detail(ip,300,&ms,&evidence))return;LGDevice *d=[LGDevice new];d.ip=@(ip);d.reachability=local?LGReachabilityHost:LGReachabilityResponded;d.lastSeen=NSDate.date;d.probeEvidence=evidence;d.latencyMS=ms;if(local)d.name=@"This iPhone";
    @synchronized(found){found[d.ip]=d;}
   }}];
  }
  [queue waitUntilAllOperationsAreFinished];if(self.generation!=generation)return;
  LGNetwork network=start.network;LGNeighbor *neighbors=calloc(1024,sizeof(*neighbors));unsigned rejected=0;size_t count=neighbors?lg_neighbors(&network,neighbors,1024,&rejected):0;
  for(size_t i=0;i<count;i++){
   NSString *ip=@(neighbors[i].ip);struct in_addr a;if(inet_pton(AF_INET,ip.UTF8String,&a)!=1)continue;unsigned host=ntohl(a.s_addr);if(host<=base||host>base+hosts)continue;
   LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;d.reachability=LGReachabilityCached;found[ip]=d;}d.neighborCached=YES;d.mac=@(neighbors[i].mac);d.identitySource=@"Local neighbor cache · unauthenticated identity";
  }free(neighbors);
  for(id object in [LGStore observations:start.networkKey]){
   if(![object isKindOfClass:NSDictionary.class])continue;NSDictionary *old=object;if(![old[@"ip"] isKindOfClass:NSString.class]||![old[@"seen"] isKindOfClass:NSNumber.class])continue;
   NSString *ip=old[@"ip"];struct in_addr a;if(inet_pton(AF_INET,ip.UTF8String,&a)!=1)continue;unsigned host=ntohl(a.s_addr);if(host<=base||host>base+hosts)continue;double time=[old[@"seen"] doubleValue];if(time<=0||NSDate.date.timeIntervalSince1970-time>7*86400)continue;
   LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;found[ip]=d;}d.previouslySeen=YES;if(!d.lastSeen)d.lastSeen=[NSDate dateWithTimeIntervalSince1970:time];
  }
  for(LGDevice *d in found.allValues)if(d.reachability==LGReachabilityResponded)[queue addOperationWithBlock:^{@autoreleasepool{if(self.generation!=generation)return;char name[256];if(lg_hostname(d.ip.UTF8String,if_nametoindex(start.network.interface),name,sizeof(name),400))d.hostname=@(name);
    char nbName[64],nbMac[18];if(lg_nbns_query(d.ip.UTF8String,150,nbName,nbMac)){if(!d.hostname.length&&nbName[0])d.hostname=@(nbName);if(!d.mac.length&&nbMac[0]){d.mac=@(nbMac);d.identitySource=@"NetBIOS self-reported MAC · not authenticated";d.macSelfReported=YES;}}}}];
  [queue waitUntilAllOperationsAreFinished];if(self.generation!=generation)return;
  LGNetworkContext *end=[LGNetworkContext current];BOOL changed=!end||![end.fingerprint isEqual:start.fingerprint];NSUInteger replies=0,cached=0,unknown=0,accepted=0,refused=0;NSMutableArray *records=[NSMutableArray new];
  for(LGDevice *d in found.allValues){d.systemProtected=[d.ip isEqual:@(network.ip)]||[d.ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;if(d.systemProtected&&!d.name.length)d.name=@"Gateway";d.identityKey=[NSString stringWithFormat:@"%@:%@",start.networkKey,d.ip];if(d.probeEvidence==1)accepted++;if(d.probeEvidence==2)refused++;if(d.reachability>=LGReachabilityResponded)replies++;else if(d.reachability==LGReachabilityCached)cached++;else unknown++;if(d.lastSeen)[records addObject:@{@"ip":d.ip,@"seen":@(d.lastSeen.timeIntervalSince1970)}];}
  NSDictionary *metrics=@{@"discovered":@(found.count),@"reachable":@(replies),@"cached":@(cached),@"unknown":@(unknown),@"rejectedNeighbors":@(rejected),@"probed":@(hosts),@"neighborView":@(lg_neighbor_view_status()),@"tcpAccepted":@(accepted),@"tcpRefused":@(refused)};
  dispatch_async(dispatch_get_main_queue(),^{if(self.generation!=generation)return;self.context=changed?end:start;self.metrics=changed?@{}:metrics;if(!changed)[LGStore saveObservations:records network:start.networkKey];if(changed){completion(@[],@"Network changed; scan discarded");return;}
   LGBonjourInventory *bonjour=[LGBonjourInventory new];[bonjour collect:^(NSDictionary *evidence){
    if(self.generation!=generation)return;LGNetworkContext *after=[LGNetworkContext current];if(!after||![after.fingerprint isEqual:start.fingerprint]){self.context=after;self.metrics=@{};completion(@[],@"Network changed during identity discovery; scan discarded");return;}
    for(LGDevice *d in found.allValues){NSDictionary *row=evidence[d.ip];if(row){d.bonjourName=row[@"name"]?:@"";d.serviceEvidence=row[@"service"]?:@"";d.typeHint=row[@"typeHint"]?:@"Device type unknown";if(!d.hostname.length)d.hostname=row[@"host"]?:@"";}}
    completion(found.allValues,@"Address responses, cached observations and history remain separate. Identity clues include bounded PTR, directed NetBIOS replies and local Bonjour advertisements; all network-provided identity is untrusted.");
   }];});
 }});
}
@end
