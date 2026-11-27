#import "LGScanner.h"
#import "LGIdentity.h"
#import "LGNetBIOS.h"
#import "LGScanSnapshot.h"
#import "Storage/LGStore.h"
#import <arpa/inet.h>
#import <net/if.h>
#import <sys/resource.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <mach/mach.h>
static double cpu_ms(void){struct rusage r;if(getrusage(RUSAGE_SELF,&r))return -1;return (r.ru_utime.tv_sec+r.ru_stime.tv_sec)*1000.0+(r.ru_utime.tv_usec+r.ru_stime.tv_usec)/1000.0;}
@implementation LGScanner
- (instancetype)init{if((self=[super init]))_engineQueue=dispatch_queue_create("com.pt94dat.languard.scanner",DISPATCH_QUEUE_SERIAL);return self;}
- (void)cancel{
 self.generation++;[self.workQueue cancelAllOperations];[self.bonjour cancel];self.bonjour=nil;
 if([self.diagnostics[@"lifecycle"] isEqual:@"running"]){NSMutableDictionary *d=[self.diagnostics mutableCopy];d[@"lifecycle"]=@"cancelled";d[@"snapshotCommitted"]=@NO;self.diagnostics=d.copy;}
}
- (void)scan:(void(^)(NSArray<LGDevice*>*,NSString*))completion{
 [self cancel];NSUInteger generation=self.generation;NSString *scanID=NSUUID.UUID.UUIDString;double began=NSProcessInfo.processInfo.systemUptime,cpu=cpu_ms();LGNetworkContext *start=[LGNetworkContext current];self.context=start;
 self.diagnostics=@{@"scanID":scanID,@"lifecycle":@"running",@"snapshotCommitted":@NO,@"generation":@(generation)};
 dispatch_async(self.engineQueue,^{@autoreleasepool{
  unsigned base=0,hosts=0;
  if(!start||!lg_subnet_hosts(start.network.address,start.network.netmask,&base,&hosts)){dispatch_async(dispatch_get_main_queue(),^{if(self.generation==generation){self.metrics=@{};self.diagnostics=@{@"scanID":scanID,@"lifecycle":start?@"unsupportedSubnet":@"noNetwork",@"snapshotCommitted":@NO};completion(@[],start?@"Unsupported subnet size":@"No local Wi-Fi IPv4 connection");}});return;}
  NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=12;self.workQueue=queue;NSMutableDictionary<NSString*,LGDevice*> *found=[NSMutableDictionary new];
  for(unsigned h=1;h<=hosts;h++){
   if(self.generation!=generation)break;
   [queue addOperationWithBlock:^{@autoreleasepool{
    if(self.generation!=generation)return;struct in_addr address={htonl(base+h)};char ip[16];inet_ntop(AF_INET,&address,ip,16);BOOL local=base+h==start.network.address;double ms=0;int evidence=local?3:0;
    if(!local&&!lg_probe_detail(ip,300,&ms,&evidence))return;LGDevice *d=[LGDevice new];d.ip=@(ip);d.reachability=local?LGReachabilityHost:LGReachabilityResponded;d.lastSeen=NSDate.date;d.probeEvidence=evidence;d.latencyMS=ms;if(local)d.name=@"This iPhone";
    @synchronized(found){found[d.ip]=d;}
   }}];
  }
  [queue waitUntilAllOperationsAreFinished];if(self.generation!=generation)return;double probesEnded=NSProcessInfo.processInfo.systemUptime;
  LGNetwork network=start.network;LGNeighbor *neighbors=calloc(1024,sizeof(*neighbors));unsigned rejected=0;size_t count=neighbors?lg_neighbors(&network,neighbors,1024,&rejected):0;LGNeighborStats ns=lg_neighbor_stats();
  for(size_t i=0;i<count;i++){
   NSString *ip=@(neighbors[i].ip);LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;d.reachability=LGReachabilityCached;found[ip]=d;}d.neighborCached=YES;d.mac=@(neighbors[i].mac);d.identitySource=@"Local neighbor cache · unauthenticated identity";
  }free(neighbors);
  NSArray *stored=[LGStore observations:start.networkKey];NSArray *history=[LGScanSnapshot history:stored now:NSDate.date.timeIntervalSince1970 address:network.address mask:network.netmask];
  for(NSDictionary *old in history){NSString *ip=old[@"ip"];LGDevice *d=found[ip];if(!d){d=[LGDevice new];d.ip=ip;found[ip]=d;}d.previouslySeen=YES;if(!d.lastSeen)d.lastSeen=[NSDate dateWithTimeIntervalSince1970:[old[@"seen"] doubleValue]];}
  NSMutableDictionary *dns=[NSMutableDictionary new];NSMutableDictionary *dnsCodes=[NSMutableDictionary new];__block NSUInteger nbReplies=0;
  for(LGDevice *d in found.allValues)if(d.reachability==LGReachabilityResponded)[queue addOperationWithBlock:^{@autoreleasepool{
   if(self.generation!=generation)return;char name[256];int code=0;LGDNSOutcome outcome=lg_hostname_detail(d.ip.UTF8String,if_nametoindex(start.network.interface),name,sizeof(name),400,&code);NSString *category=@[@"notAttempted",@"resolved",@"applicationDeadline",@"noRecordReported",@"resolverFailure",@"malformedReply"][outcome];d.dnsOutcome=category;if(outcome==LGDNSResolved)d.hostname=@(name);
   @synchronized(dns){dns[category]=@([dns[category] unsignedIntegerValue]+1);if(code)dnsCodes[[NSString stringWithFormat:@"%d",code]]=@([dnsCodes[[NSString stringWithFormat:@"%d",code]] unsignedIntegerValue]+1);}
   if(self.generation!=generation)return;char nbName[64],nbMac[18];if(lg_nbns_query(d.ip.UTF8String,150,nbName,nbMac)){@synchronized(dns){nbReplies++;}if(!d.hostname.length&&nbName[0])d.hostname=@(nbName);if(!d.mac.length&&nbMac[0]){d.mac=@(nbMac);d.identitySource=@"NetBIOS self-reported MAC · not authenticated";d.macSelfReported=YES;}}
  }}];
  [queue waitUntilAllOperationsAreFinished];if(self.generation!=generation)return;double namesEnded=NSProcessInfo.processInfo.systemUptime;
  for(LGDevice *d in found.allValues){d.systemProtected=[d.ip isEqual:@(network.ip)]||[d.ip isEqual:@(network.gateway)];d.protectedDevice=d.systemProtected;if(d.systemProtected&&!d.name.length)d.name=@"Gateway";d.identityKey=[NSString stringWithFormat:@"%@:%@",start.networkKey,d.ip];}
  NSDictionary *counts=[LGScanSnapshot counts:found.allValues];NSMutableDictionary *metrics=[counts mutableCopy];metrics[@"rejectedNeighbors"]=@(rejected);metrics[@"probed"]=@(hosts);metrics[@"neighborView"]=@(ns.view);metrics[@"scanID"]=scanID;
  NSDictionary *neighborReport=@{@"view":@(ns.view),@"apiErrno":@(ns.apiError),@"records":@(ns.records),@"candidates":@(ns.candidates),@"usableUnique":@(ns.accepted),@"duplicate":@(ns.duplicate),@"conflicting":@(ns.conflicting),@"malformed":@(ns.malformed),@"unsupported":@(ns.unsupported),@"incomplete":@(ns.incomplete),@"placeholderPattern":@(ns.placeholder),@"zero":@(ns.zero),@"multicast":@(ns.multicast),@"uniqueRejectedAddresses":@(ns.uniqueRejected),@"capacityDropped":@(ns.capacityDropped)};
  dispatch_async(dispatch_get_main_queue(),^{if(self.generation!=generation)return;
   LGNetworkContext *end=[LGNetworkContext current];if(!end||![end.fingerprint isEqual:start.fingerprint]){self.context=end;self.metrics=@{};self.diagnostics=@{@"scanID":scanID,@"lifecycle":@"networkChanged",@"snapshotCommitted":@NO};completion(@[],@"Network changed; scan discarded");return;}
   self.bonjour=[LGBonjourInventory new];LGBonjourInventory *inventory=self.bonjour;
   [inventory collect:^(NSDictionary<NSString*,NSDictionary*> *evidence){
    if(self.generation!=generation)return;LGNetworkContext *after=[LGNetworkContext current];if(!after||![after.fingerprint isEqual:start.fingerprint]){self.context=after;self.metrics=@{};self.diagnostics=@{@"scanID":scanID,@"lifecycle":@"networkChanged",@"snapshotCommitted":@NO};completion(@[],@"Network changed; scan discarded");return;}
    NSUInteger matched=0;for(LGDevice *d in found.allValues){NSDictionary *row=evidence[d.ip];if(row){matched++;d.bonjourName=row[@"name"]?:@"";d.serviceEvidence=row[@"service"]?:@"";d.typeHint=row[@"typeHint"]?:@"Device type unknown";if(!d.hostname.length)d.hostname=row[@"host"]?:@"";}}
    NSMutableArray *records=[NSMutableArray new];for(LGDevice *d in found.allValues)if(d.lastSeen)[records addObject:@{@"ip":d.ip,@"seen":@(d.lastSeen.timeIntervalSince1970)}];[LGStore saveObservations:[LGScanSnapshot history:records now:NSDate.date.timeIntervalSince1970 address:network.address mask:network.netmask] network:start.networkKey];
    mach_task_basic_info_data_t memory={0};mach_msg_type_number_t size=MACH_TASK_BASIC_INFO_COUNT;kern_return_t memoryCode=task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&memory,&size);
    self.context=start;self.metrics=metrics.copy;self.diagnostics=@{@"scanID":scanID,@"generation":@(generation),@"lifecycle":@"completed",@"snapshotCommitted":@YES,@"counts":counts,@"neighbor":neighborReport,@"dns":@{@"outcomes":dns.copy,@"apiCodes":dnsCodes.copy},@"netbiosReplies":@(nbReplies),@"bonjour":inventory.diagnostics,@"bonjourMatchedAddresses":@(matched),@"history":@{@"input":@(stored.count),@"retainedUnique":@(history.count),@"filteredOrDuplicate":@(stored.count-history.count)},@"timingMS":@{@"probes":@((probesEnded-began)*1000),@"identity":@((namesEnded-probesEnded)*1000),@"total":@((NSProcessInfo.processInfo.systemUptime-began)*1000),@"processCPU":@(cpu_ms()-cpu)},@"residentBytes":@(memoryCode==KERN_SUCCESS?memory.resident_size:0),@"memoryAPICode":@(memoryCode),@"budgets":@{@"workers":@12,@"tcpMS":@300,@"ptrMS":@400,@"nbnsMS":@150,@"bonjourMS":@1500}};
    self.bonjour=nil;completion(found.allValues,@"One committed snapshot. Responded = accepted + refused + local. History is not current connectivity; network names are self-reported.");
   }];
  });
 }});
}
@end
